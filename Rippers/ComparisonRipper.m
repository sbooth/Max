/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "ComparisonRipper.h"
#import "Rip.h"
#import "SectorRange.h"
#import "BitArray.h"
#import "LogController.h"
#import "MallocException.h"
#import "StopException.h"
#import "IOException.h"
#import "MissingResourceException.h"
#import "CoreAudioException.h"

#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <sys/stat.h>		// stat
#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close
#include <paths.h>			// _PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_SUFFIX		".rip"
#define TEMPFILE_PATTERN	"MaxXXXXXXXX" TEMPFILE_SUFFIX

@interface ComparisonRipper (Private)
- (void)		logMessage:(NSString *)message;
- (NSString *)	createTemporaryFile;
- (void)		ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file;
@end

@implementation ComparisonRipper

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ComparisonRipperDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"ComparisonRipperDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ComparisonRipper"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName
{
	if((self = [super initWithSectors:sectors deviceName:deviceName])) {
		_drive				= [[Drive alloc] initWithDeviceName:deviceName];
		
		_requiredMatches	= [[NSUserDefaults standardUserDefaults] integerForKey:@"comparisonRipperRequiredMatches"];
		_maximumRetries		= [[NSUserDefaults standardUserDefaults] integerForKey:@"comparisonRipperMaximumRetries"];
		_useHashes			= [[NSUserDefaults standardUserDefaults] boolForKey:@"comparisonRipperUseHashes"];

		_sectorsRead		= 0;
		
		// Determine the size of the track(s) we are ripping
		_grandTotalSectors = [[_sectors valueForKeyPath:@"@sum.length"] unsignedIntValue];
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{	
	[_drive release];
	[super dealloc];
}

- (NSString *)			deviceName									{ return [_drive deviceName]; }

- (unsigned)			requiredMatches								{ return _requiredMatches; }
- (unsigned)			maximumRetries								{ return _maximumRetries; }

- (void)				setRequiredMatches:(unsigned)matches		{ _requiredMatches = matches; }
- (void)				setMaximumRetries:(unsigned)retries			{ _maximumRetries = retries; }

- (BOOL)				useHashes									{ return _useHashes; }
- (void)				setUseHashes:(BOOL)useHashes				{ _useHashes = useHashes; }

- (void)				logMessage:(NSString *)message
{
	if([self logActivity]) {
		[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:message waitUntilDone:NO];
	}
}

- (oneway void) ripToFile:(NSString *)filename
{
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		outputASBD;
	NSEnumerator					*enumerator;
	SectorRange						*range;
	uint16_t						driveSpeed;
	
	// Tell our owner we are starting
	_startTime = [NSDate date];
	[_delegate setStartTime:_startTime];
	[_delegate setStarted];
	
	@try {
		// Setup output file type (same)
		bzero(&outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio
		outputASBD.mSampleRate			= 44100.f;
		outputASBD.mFormatID			= kAudioFormatLinearPCM;
		outputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian;
		outputASBD.mBytesPerPacket		= 4;
		outputASBD.mFramesPerPacket		= 1;
		outputASBD.mBytesPerFrame		= 4;
		outputASBD.mChannelsPerFrame	= 2;
		outputASBD.mBitsPerChannel		= 16;
		
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &outputASBD, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Save the drive speed
		driveSpeed = [_drive speed];
		
		// Process each sector range
		enumerator = [_sectors objectEnumerator];
		while((range = [enumerator nextObject])) {
			[self ripSectorRange:range toFile:extAudioFileRef];
			_sectorsRead += [range length];
		}

		// Restore drive speed
		[_drive setSpeed:driveSpeed];
	}
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException						*exception;
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file
{
//	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	int16_t				*buffer				= NULL;
	int8_t				sectorBuffer		[ kCDSectorSizeCDDA ];
	unsigned			bufferLen			= 0;
	unsigned			sectorsRead			= 0;
	unsigned			sectorCount			= 0;
	unsigned			startSector			= 0;
	unsigned			sectorsRemaining	= 0;
	SectorRange			*readRange			= nil;
	SectorRange			*blockRange			= nil;
	OSStatus			err					= noErr;
	unsigned			totalSectors		= 0;
	unsigned			sectorsToRead		= 0;
	unsigned long		iterations			= 0;
	AudioBufferList		bufferList;
	UInt32				frameCount			= 0;
	NSMutableArray		*rips				= nil;
	BitArray			*sectorStatus		= nil;
	Rip					*masterRip			= nil;
	Rip					*rip				= nil;
	Rip					*master				= nil;
	Rip					*comparator			= nil;
	NSDate				*phaseStartTime		= nil;
	BOOL				gotMatch;
	unsigned			i;
	unsigned			sector;
	unsigned			sectorIndex;
	unsigned			masterIndex;
	unsigned			comparatorIndex;
	unsigned			matchCount;
	unsigned char		*masterHash;
	unsigned			blockEnd;
	unsigned			retries;
	unsigned			blockPadding;

	
	@try {
		
		// Allocate the master rip
		masterRip = [[[Rip alloc] initWithSectorRange:range] autorelease];
		[masterRip setFilename:[self createTemporaryFile]];
		[masterRip setCalculateHashes:NO];

		// Allocate the array that will hold the individual rips
		rips = [[[NSMutableArray alloc] initWithCapacity:[self requiredMatches]] autorelease];
		
		// Allocate a buffer to hold the ripped data
		bufferLen	= [range length] <  1024 ? [range length] : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA);
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// Allocate the bit array
		sectorStatus = [[[BitArray alloc] init] autorelease];
		[sectorStatus setBitCount:[range length]];
		
		// ===============
		// INITIAL RIPPING
		// ===============
		// Rip the entire sector range the minimum number of times to achieve the required matches
		
		// Use maximum speed for the initial extraction
		[self logMessage:NSLocalizedStringFromTable(@"Setting drive speed to maximum", @"Log", @"")];
		[_drive setSpeed:kCDSpeedMax];
		
		retries			= 0;
		
		// Update UI based on the current ripping phase only- too hard to predict otherwise
		totalSectors	= [self requiredMatches] * [range length];
		sectorsToRead	= [self requiredMatches] * [range length];
		phaseStartTime	= [NSDate date];

		[_delegate setPhase:NSLocalizedStringFromTable(@"Ripping", @"General", @"")];
		
		for(i = 0; i < [self requiredMatches]; ++i) {
			// Clear the drive's cache
			[_drive clearCache:range];
			
			// Allocate the rip object
			rip = [[Rip alloc] initWithSectorRange:range];
			
			// Associate it with the temporary file
			[rip setFilename:[self createTemporaryFile]];
			
			// Don't calculate SHA-256 hashes unnecessarily
			[rip setCalculateHashes:[self useHashes]];
			
			// Place it in our array of objects
			[rips addObject:[rip autorelease]];
			
			// Extract the audio
			sectorsRemaining	= [range length];
			
			while(0 < sectorsRemaining) {
				
				// Set up the parameters for this read
				startSector		= [range firstSector] + [range length] - sectorsRemaining;
				sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
				readRange		= [SectorRange rangeWithFirstSector:startSector sectorCount:sectorCount];

				// Extract the audio from the disc
				[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Ripping sectors %i - %i", @"Log", @""), [readRange firstSector], [readRange lastSector]]];				
				sectorsRead		= [_drive readAudio:buffer sectorRange:readRange];
				
				if(sectorCount != sectorsRead) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Log", @"") userInfo:nil];
				}
				
				// Place the data in the Rip object
				[rip setBytes:buffer forSectorRange:readRange];
				
				// Housekeeping
				sectorsRemaining	-= [readRange length];
				sectorsToRead		-= [readRange length];
				
				// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
				// iterations the user will think the program is unresponsive
				// Distributed Object calls are expensive, so only perform them every few iterations
				if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
					
					// Check if we should stop, and if so throw an exception
					if([_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					// Update UI
					double percentComplete = ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
					NSTimeInterval interval = -1.0 * [phaseStartTime timeIntervalSinceNow];
					unsigned int secondsRemaining = interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
					NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
					
					[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
				}
				
				++iterations;				
			}
		}
		
		// Main loop
		for(;;) {
			
			// ===============
			// COMPARISON LOOP
			// ===============
			// Iterate over each sector, checking each for the required number of matches
			
			// Update UI based on the current ripping phase only- too hard to predict otherwise
			totalSectors	= [range length];
			sectorsToRead	= [sectorStatus countOfZeroes];
			phaseStartTime	= [NSDate date];
			
			[_delegate setPhase:NSLocalizedStringFromTable(@"Verifying", @"General", @"")];
			[self logMessage:NSLocalizedStringFromTable(@"Verifying rip integrity", @"Log", @"")];
			
			for(sector = [range firstSector]; sector <= [range lastSector]; ++sector) {
				
				// Initial conditions
				matchCount		= 0;
				sectorIndex		= [range indexForSector:sector];
				
				// If this sector has already been matched, skip it
				if([sectorStatus valueAtIndex:sectorIndex]) {
					continue;
				}

				// Use each rip as a "master", comparing the hash for the sector in question
				// to every other rip we've generated that contains the sector
				for(masterIndex = 0; masterIndex < [rips count] && NO == [sectorStatus valueAtIndex:sectorIndex]; ++masterIndex) {
					
					master = [rips objectAtIndex:masterIndex];
					
					// Skip this rip if it doesn't contain the sector of interest
					if(NO == [master containsSector:sector]) {
						continue;
					}
					
					// Determine whether to compare based on SHA-256 hash or the sector's data
					if([self useHashes]) {
						masterHash = [master hashForSector:sector];
					}
					else {
						[master getBytes:sectorBuffer forSector:sector];
					}
					
					for(comparatorIndex = 0; comparatorIndex < [rips count] && NO == [sectorStatus valueAtIndex:sectorIndex]; ++comparatorIndex) {
												
						comparator = [rips objectAtIndex:comparatorIndex];
						
						// Skip this rip if it doesn't contain the sector of interest
						if(NO == [comparator containsSector:sector]) {
							continue;
						}
						
						// Determine if the two sectors are equal
						gotMatch = NO;
						if([self useHashes]) {
							gotMatch = [comparator sector:sector hasHash:masterHash];
						}
						else {
							gotMatch = [comparator sector:sector matchesSector:sectorBuffer];
						}
						
						// If the sectors are equal (hashes or raw bytes), increment the match count
						// (don't compare to ourselves but ensure a match)
						if(masterIndex == comparatorIndex || gotMatch) {
							++matchCount;
							
							//NSLog(@"Sector %i matches in rips %02i and %02i (%i)", sector, masterIndex, comparatorIndex, matchCount);
							
							// We've found the required number of matches- save this sector
							if([self requiredMatches] == matchCount) {
								
								// We only need to grab the sector's raw bytes if are comparing by hash
								if([self useHashes]) {
									[master getBytes:sectorBuffer forSector:sector];
								}
								
								[masterRip setBytes:sectorBuffer forSector:sector];
								[sectorStatus setValue:YES forIndex:sectorIndex];
							}
						}
					}
				}
				
				// Distributed Object calls are expensive, so only perform them every few iterations
				if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
					
					// Check if we should stop, and if so throw an exception
					if([_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					// Update UI
					 double percentComplete = ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
					 NSTimeInterval interval = -1.0 * [phaseStartTime timeIntervalSinceNow];
					 unsigned int secondsRemaining = interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
					 NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
					 
					 [_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
				}
				
				++iterations;				
				--sectorsToRead;				
			}
			
			// =====================
			// TERMINATION CONDITION
			// =====================
			if([sectorStatus allOnes]) {
				break;
			}
			else {
				++retries;

				// Slow drive down if we've had too many errors (too many is defined arbitrarily here as more retries
				// than the number of sector matches required)
				if([self requiredMatches] < retries) {
					[_drive setSpeed:kCDSpeedMin];
					[self logMessage:NSLocalizedStringFromTable(@"Setting drive speed to minimum", @"Log", @"")];
				}
				
				// Abort rip if too many read errors have occurred
				if([self maximumRetries] < retries) {
					[self logMessage:NSLocalizedStringFromTable(@"Retry limit exceeded", @"Log", @"")];
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"The retry limit was exceeded.", @"Exceptions", @"") userInfo:nil];
				}
			}
			
			// ===============
			// RE-RIPPING LOOP
			// ===============
			// For all sectors that don't have the required number of matches, generate a new rip

			// Update UI based on the current ripping phase only- too hard to predict otherwise
			totalSectors	= [sectorStatus countOfZeroes];
			sectorsToRead	= [sectorStatus countOfZeroes];
			phaseStartTime	= [NSDate date];
			
			[_delegate setPhase:NSLocalizedStringFromTable(@"Re-ripping", @"General", @"")];

			for(i = 0; i < [range length]; ++i) {
				
				// If this sector has already been matched, skip it
				if([sectorStatus valueAtIndex:i]) {
					continue;
				}
				
				// Determine if there are multiple mismatched sectors in a row, and if so, how many
				blockEnd = i;
				while(NO == [sectorStatus valueAtIndex:blockEnd + 1] && blockEnd + 1 < [range length]) {
					++blockEnd;
				}
				
				// Log this message here, instead of in the comparison loop, to avoid repetitive messages
				if(blockEnd == i) {
					[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Mismatch for sector %i", @"Log", @""), [range sectorForIndex:i]]];
				}
				else {
					[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Mismatches for sectors %i - %i", @"Log", @""), [range sectorForIndex:i], [range sectorForIndex:blockEnd]]];
				}
				
				// Adjust boundaries so drive is up to speed when it reaches the problem area if
				// too many errors have occurred
				// (I assume that a larger read will give better/more consistent results- may not be a correct assumption)
				if([self requiredMatches] < retries) {
					blockPadding	= 10 * retries;
					i				= (i > blockPadding ? i - blockPadding : 0); 
					blockEnd		= (blockEnd + blockPadding < [range length] ? blockEnd + blockPadding : [range length] - 1); 
				}
				
				// Now just re-rip the block
				blockRange = [SectorRange rangeWithFirstSector:[range sectorForIndex:i] lastSector:[range sectorForIndex:blockEnd]];

				// Clear the drive's cache
				[_drive clearCache:blockRange];
				
				// Allocate the rip object
				rip = [[Rip alloc] initWithSectorRange:blockRange];
				
				// Associate it with the temporary file
				[rip setFilename:[self createTemporaryFile]];
				
				// Don't calculate SHA-256 hashes unnecessarily
				[rip setCalculateHashes:[self useHashes]];

				// Place it in our array of objects
				[rips addObject:[rip autorelease]];
				
				// Extract the audio
				sectorsRemaining	= [blockRange length];

				while(0 < sectorsRemaining) {
					
					// Set up the parameters for this read
					startSector		= [blockRange firstSector] + [blockRange length] - sectorsRemaining;
					sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
					readRange		= [SectorRange rangeWithFirstSector:startSector sectorCount:sectorCount];
					
					// Extract the audio from the disc
					if(1 == [readRange length]) {
						[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Re-ripping sector %i", @"Log", @""), [readRange firstSector]]];
					}
					else {
						[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Re-ripping sectors %i - %i", @"Log", @""), [readRange firstSector], [readRange lastSector]]];
					}
					sectorsRead		= [_drive readAudio:buffer sectorRange:readRange];
					
					if(sectorCount != sectorsRead) {
						@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"") userInfo:nil];
					}
					
					// Place the data in the Rip object
					[rip setBytes:buffer forSectorRange:readRange];
					
					// Housekeeping
					sectorsRemaining -= [readRange length];
					
					// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
					// iterations the user will think the program is unresponsive
					// Distributed Object calls are expensive, so only perform them every few iterations
					if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
						
						// Check if we should stop, and if so throw an exception
						if([_delegate shouldStop]) {
							@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
						}
						
						// Update UI
						double percentComplete = ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
						NSTimeInterval interval = -1.0 * [phaseStartTime timeIntervalSinceNow];
						unsigned int secondsRemaining = interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
						NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];

						[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
					}
					
					++iterations;
					sectorsToRead -= [readRange length];
				}
				
				// Adjust loop index
				i = blockEnd;
			}
									
		}

		// ===========
		// SAVE OUTPUT
		// ===========
		// Just place each chunk from the master rip into the AIFF file

		sectorsRemaining	= [range length];
		
		// Update UI based on the current ripping phase only- too hard to predict otherwise
		totalSectors		= [range length];
		phaseStartTime		= [NSDate date];
		
		[_delegate setPhase:NSLocalizedStringFromTable(@"Saving", @"General", @"")];
		[self logMessage:NSLocalizedStringFromTable(@"Generating output", @"Log", @"")];
		
		while(0 < sectorsRemaining) {
			
			// Set up the parameters for this read
			startSector		= [range firstSector] + [range length] - sectorsRemaining;
			sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
			readRange		= [SectorRange rangeWithFirstSector:startSector sectorCount:sectorCount];
			
			// Grab the master rip's data
			[masterRip getBytes:buffer forSectorRange:readRange];
			
			// Convert to big endian byte ordering for the AIFF file
			swab(buffer, buffer, [readRange byteSize]);
			
			// Put the data in an AudioBufferList
			bufferList.mNumberBuffers					= 1;
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= [readRange byteSize];
			bufferList.mBuffers[0].mNumberChannels		= 2;
			
			frameCount									= [readRange byteSize] / 4;
			
			// Write the data
			err = ExtAudioFileWrite(file, frameCount, &bufferList);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Housekeeping
			sectorsRemaining -= [readRange length];

			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				 double percentComplete = ((double)(totalSectors - sectorsRemaining)/(double) totalSectors) * 100.0;
				 NSTimeInterval interval = -1.0 * [phaseStartTime timeIntervalSinceNow];
				 unsigned int secondsRemaining = interval / ((double)(totalSectors - sectorsRemaining)/(double) totalSectors) - interval;
				 NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				 
				 [_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
	}
	
	@finally {
		struct stat			sourceStat;
		NSException			*exception;

		free(buffer);
		
		// Delete temporary files
		for(i = 0; i < [rips count]; ++i) {
			rip = [rips objectAtIndex:i];
			if(0 == stat([[rip filename] fileSystemRepresentation], &sourceStat) && -1 == unlink([[rip filename] fileSystemRepresentation])) {
				exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the temporary file.", @"Exceptions", @"")
													 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}	
		}
		
		if(0 == stat([[masterRip filename] fileSystemRepresentation], &sourceStat) && -1 == unlink([[masterRip filename] fileSystemRepresentation])) {
			exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the temporary file.", @"Exceptions", @"") 
												 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	
//		[pool release];
	}
}

- (NSString *) createTemporaryFile
{
	int					fd				= -1;
	char				*path			= NULL;
	const char			*tmpDir;
	ssize_t				tmpDirLen;
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);
	NSString			*result			= nil;
	
	@try {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
			tmpDir = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] stringByAppendingString:@"/"] fileSystemRepresentation];
		}
		else {
			tmpDir = _PATH_TMP;
		}
		
		validateAndCreateDirectory([NSString stringWithCString:tmpDir encoding:NSASCIIStringEncoding]);
		
		tmpDirLen	= strlen(tmpDir);
		path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
		if(NULL == path) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		memcpy(path, tmpDir, tmpDirLen);
		memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
		path[tmpDirLen + patternLen] = '\0';
		
		fd = mkstemps(path, strlen(TEMPFILE_SUFFIX));
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create a temporary file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		result = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
	}
	
	@finally {
		free(path);
		
		// And close it
		if(-1 != fd && -1 == close(fd)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the temporary file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
	
	return (nil != result ? [[result retain] autorelease] : nil);
}

@end
