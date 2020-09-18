/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
#import "StopException.h"
#import "UtilityFunctions.h"

#include <IOKit/storage/IOCDTypes.h>

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
		NSAssert1(nil != defaultsValuesPath, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"ComparisonRipperDefaults.plist");

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
		_useC2				= [[NSUserDefaults standardUserDefaults] boolForKey:@"comparisonRipperUseC2"];

		_sectorsRead		= 0;
		
		// Determine the size of the track(s) we are ripping
		_grandTotalSectors = [[_sectors valueForKeyPath:@"@sum.length"] unsignedIntValue];
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{	
	[_drive release];	_drive = nil;
	
	[super dealloc];
}

- (NSString *)			deviceName									{ return [_drive deviceName]; }

- (int)					driveOffset									{ return _driveOffset; }
- (void)				setDriveOffset:(int)driveOffset				{ _driveOffset = driveOffset; }

- (NSUInteger)			requiredMatches								{ return _requiredMatches; }
- (void)				setRequiredMatches:(NSUInteger)matches		{ _requiredMatches = matches; }

- (NSUInteger)			maximumRetries								{ return _maximumRetries; }
- (void)				setMaximumRetries:(NSUInteger)retries			{ _maximumRetries = retries; }

- (BOOL)				useHashes									{ return _useHashes; }
- (void)				setUseHashes:(BOOL)useHashes				{ _useHashes = useHashes; }

- (BOOL)				useC2										{ return _useC2; }
- (void)				setUseC2:(BOOL)useC2						{ _useC2 = useC2; }

- (void)				logMessage:(NSString *)message
{
	if([self logActivity]) {
		[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:message waitUntilDone:NO];
	}
}

- (oneway void) ripToFile:(NSString *)filename
{
	OSStatus						err;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		outputASBD;
	SectorRange						*range;
	uint16_t						driveSpeed;
	
	// Tell our owner we are starting
	_startTime = [NSDate date];
	[[self delegate] setStartTime:_startTime];
	[[self delegate] setStarted:YES];
	
	@try {
		// Setup output file type (same)
		bzero(&outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio is what CD-DA gives us
		outputASBD.mSampleRate			= 44100.f;
		outputASBD.mFormatID			= kAudioFormatLinearPCM;
		outputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		outputASBD.mBytesPerPacket		= 4;
		outputASBD.mFramesPerPacket		= 1;
		outputASBD.mBytesPerFrame		= 4;
		outputASBD.mChannelsPerFrame	= 2;
		outputASBD.mBitsPerChannel		= 16;
		
		err = AudioFileCreateWithURL((CFURLRef)[NSURL fileURLWithPath:filename], kAudioFileCAFType, &outputASBD, kAudioFileFlags_EraseFile, &audioFile);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize", UTCreateStringForOSType(err));
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID", UTCreateStringForOSType(err));
		
		// Save the drive speed
		driveSpeed = [_drive speed];
		
		// Process each sector range
		for(range in _sectors) {
			[self ripSectorRange:range toFile:extAudioFileRef];
			_sectorsRead += [range length];
		}

		// Restore drive speed
		[_drive setSpeed:driveSpeed];
	}
	
	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		NSException						*exception;
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [NSException exceptionWithName:@"CoreAudioException"
												reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [NSException exceptionWithName:@"CoreAudioException"
												 reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the device file descriptor
		[_drive closeDevice];
	}
	
	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file
{
//	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];

	int8_t				*buffer				= NULL;
	int8_t				*audioBuffer		= NULL;
	int8_t				*c2Buffer			= NULL;
	int8_t				*sectorAlias		= NULL;
	
	int8_t				sectorBuffer		[ kCDSectorSizeCDDA ];
	NSUInteger			bufferLen			= 0;
	
	NSUInteger			sectorsRead			= 0;
	NSUInteger			sectorCount			= 0;
	NSUInteger			startSector			= 0;
	NSUInteger			sectorsRemaining	= 0;
	SectorRange			*readRange			= nil;
	SectorRange			*blockRange			= nil;
	OSStatus			err					= noErr;
	NSUInteger			totalSectors		= 0;
	NSUInteger			sectorsToRead		= 0;
	NSUInteger			iterations			= 0;
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
	NSUInteger			i, j, k;
	NSUInteger			sector;
	NSUInteger			sectorIndex;
	NSUInteger			masterIndex;
	NSUInteger			comparatorIndex;
	NSUInteger			matchCount;
	unsigned char		*masterHash;
	NSUInteger			blockEnd;
	NSUInteger			retries;
	NSUInteger			blockPadding;
	double				percentComplete;
	NSTimeInterval		interval;
	NSUInteger			secondsRemaining;
	
	@try {
		
		// Allocate the master rip
		masterRip = [[[Rip alloc] initWithSectorRange:range] autorelease];
		[masterRip setFilename:[self createTemporaryFile]];
		[masterRip setCalculateHashes:NO];

		// Allocate the array that will hold the individual rips
		rips = [[[NSMutableArray alloc] initWithCapacity:[self requiredMatches]] autorelease];
		
		// Allocate buffers to hold the ripped data
		bufferLen	= [range length] <  1024 ? [range length] : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA + kCDSectorSizeErrorFlags);
		audioBuffer	= calloc(bufferLen, kCDSectorSizeCDDA);
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		NSAssert(NULL != audioBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		if([self useC2]) {
			c2Buffer	= calloc(bufferLen, kCDSectorSizeErrorFlags);
			NSAssert(NULL != c2Buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
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

		[[self delegate] setPhase:NSLocalizedStringFromTable(@"Ripping", @"General", @"")];
		
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
				readRange		= [SectorRange sectorRangeWithFirstSector:startSector sectorCount:sectorCount];

				// Extract the audio from the disc
				[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Ripping sectors %lu - %lu", @"Log", @""), (unsigned long)[readRange firstSector], (unsigned long)[readRange lastSector]]];
				sectorsRead		= [_drive readAudioAndErrorFlags:buffer sectorRange:readRange];
				
				NSAssert(sectorCount == sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Log", @""));
				
				// Copy audio and (optionally) C2 data to their respective buffers
				for(j = 0; j < sectorsRead; ++j) {
					sectorAlias = buffer + (j * (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags));
					memcpy(audioBuffer + (j * kCDSectorSizeCDDA), sectorAlias, kCDSectorSizeCDDA);

					if([self useC2]) {
						memcpy(c2Buffer + (j * kCDSectorSizeErrorFlags), sectorAlias + kCDSectorSizeCDDA, kCDSectorSizeErrorFlags);
					}
					
					//memcpy(q + (j * kCDSectorSizeQSubchannel), sectorAlias + kCDSectorSizeCDDA + kCDSectorSizeErrorFlags, kCDSectorSizeQSubchannel);
				}

				// Check for C2 errors
				if([self useC2]) {
					for(j = 0; j < kCDSectorSizeErrorFlags * sectorsRead; ++j) {
						if(c2Buffer[j]) {
							for(k = 0; k < 8; ++k) {
								if((1 << k) & c2Buffer[j]) {
									[self logMessage:[NSString stringWithFormat:@"C2 error for sector %lu", [readRange firstSector] + (8 * j) + k]];
								}
							}					
						}
					}
				}

				// Place the data in the Rip object
				[rip setBytes:audioBuffer forSectorRange:readRange];

				// Store C2 errors
				if([self useC2]) {
					[rip setErrorFlags:c2Buffer forSectorRange:readRange];
				}
				
				// Housekeeping
				sectorsRemaining	-= [readRange length];
				sectorsToRead		-= [readRange length];
				
				// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
				// iterations the user will think the program is unresponsive
				// Distributed Object calls are expensive, so only perform them every few iterations
				if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
					
					// Check if we should stop, and if so throw an exception
					if([[self delegate] shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					// Update UI
					percentComplete		= ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
					interval			= -1.0 * [phaseStartTime timeIntervalSinceNow];
					secondsRemaining	= interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
					
					[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
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
			
			[[self delegate] setPhase:NSLocalizedStringFromTable(@"Verifying", @"General", @"")];
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
					
					// Skip this rip if a C2 error was detected for the sector of interest
					if([self useC2] && [master sectorHasError:sector]) {
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
						
						// Skip this rip if a C2 error was detected for the sector of interest
						if([self useC2] && [comparator sectorHasError:sector]) {
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
					if([[self delegate] shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					// Update UI
					 percentComplete	= ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
					 interval			= -1.0 * [phaseStartTime timeIntervalSinceNow];
					 secondsRemaining	= interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
					 
					 [[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
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
					@throw [NSException exceptionWithName:@"IOException"
													reason:NSLocalizedStringFromTable(@"The retry limit was exceeded.", @"Exceptions", @"")
												 userInfo:nil];
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
			
			[[self delegate] setPhase:NSLocalizedStringFromTable(@"Re-ripping", @"General", @"")];

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
					[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Mismatch for sector %lu", @"Log", @""), (unsigned long)[range sectorForIndex:i]]];
				}
				else {
					[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Mismatches for sectors %lu - %lu", @"Log", @""), (unsigned long)[range sectorForIndex:i], (unsigned long)[range sectorForIndex:blockEnd]]];
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
				blockRange = [SectorRange sectorRangeWithFirstSector:[range sectorForIndex:i] lastSector:[range sectorForIndex:blockEnd]];

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
					readRange		= [SectorRange sectorRangeWithFirstSector:startSector sectorCount:sectorCount];
					
					// Extract the audio from the disc
					if(1 == [readRange length]) {
						[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Re-ripping sector %lu", @"Log", @""), (unsigned long)[readRange firstSector]]];
					}
					else {
						[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Re-ripping sectors %lu - %lu", @"Log", @""), (unsigned long)[readRange firstSector], (unsigned long)[readRange lastSector]]];
					}
					sectorsRead		= [_drive readAudioAndErrorFlags:buffer sectorRange:readRange];
					
					NSAssert(sectorCount == sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Log", @""));
					
					// Copy audio and (optionally) C2 data to their respective buffers
					for(j = 0; j < sectorsRead; ++j) {
						sectorAlias = buffer + (j * (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags));
						memcpy(audioBuffer + (j * kCDSectorSizeCDDA), sectorAlias, kCDSectorSizeCDDA);
						
						if([self useC2]) {
							memcpy(c2Buffer + (j * kCDSectorSizeErrorFlags), sectorAlias + kCDSectorSizeCDDA, kCDSectorSizeErrorFlags);
						}
						
						//memcpy(q + (j * kCDSectorSizeQSubchannel), sectorAlias + kCDSectorSizeCDDA + kCDSectorSizeErrorFlags, kCDSectorSizeQSubchannel);
					}
					
					// Check for C2 errors
					if([self useC2]) {
						for(j = 0; j < kCDSectorSizeErrorFlags * sectorsRead; ++j) {
							if(c2Buffer[j]) {
								for(k = 0; k < 8; ++k) {
									if((1 << k) & c2Buffer[j]) {
										[self logMessage:[NSString stringWithFormat:@"C2 error for sector %lu", [readRange firstSector] + (8 * j) + k]];
									}
								}					
							}
						}
					}
					
					// Place the data in the Rip object
					[rip setBytes:audioBuffer forSectorRange:readRange];
					
					// Store C2 errors
					if([self useC2]) {
						[rip setErrorFlags:c2Buffer forSectorRange:readRange];
					}
					
					// Housekeeping
					sectorsRemaining -= [readRange length];
					
					// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
					// iterations the user will think the program is unresponsive
					// Distributed Object calls are expensive, so only perform them every few iterations
					if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
						
						// Check if we should stop, and if so throw an exception
						if([[self delegate] shouldStop]) {
							@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
						}
						
						// Update UI
						percentComplete		= ((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0;
						interval			= -1.0 * [phaseStartTime timeIntervalSinceNow];
						secondsRemaining	= interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;

						[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
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
		// Just place each chunk from the master rip into the CAF file

		sectorsRemaining	= [range length];
		
		// Update UI based on the current ripping phase only- too hard to predict otherwise
		totalSectors		= [range length];
		phaseStartTime		= [NSDate date];
		
		[[self delegate] setPhase:NSLocalizedStringFromTable(@"Saving", @"General", @"")];
		[self logMessage:NSLocalizedStringFromTable(@"Generating output", @"Log", @"")];
		
		while(0 < sectorsRemaining) {
			
			// Set up the parameters for this read
			startSector		= [range firstSector] + [range length] - sectorsRemaining;
			sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
			readRange		= [SectorRange sectorRangeWithFirstSector:startSector sectorCount:sectorCount];
			
			// Grab the master rip's data
			[masterRip getBytes:buffer forSectorRange:readRange];
			
			// Convert to big endian byte ordering 
			swab(buffer, buffer, [readRange byteSize]);
			
			// Put the data in an AudioBufferList
			bufferList.mNumberBuffers					= 1;
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= (UInt32)[readRange byteSize];
			bufferList.mBuffers[0].mNumberChannels		= 2;
			
			frameCount									= (UInt32)([readRange byteSize] / 4);
			
			// Write the data
			err = ExtAudioFileWrite(file, frameCount, &bufferList);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite", UTCreateStringForOSType(err));
			
			// Housekeeping
			sectorsRemaining -= [readRange length];

			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([[self delegate] shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				 percentComplete	= ((double)(totalSectors - sectorsRemaining)/(double) totalSectors) * 100.0;
				 interval			= -1.0 * [phaseStartTime timeIntervalSinceNow];
				 secondsRemaining	= interval / ((double)(totalSectors - sectorsRemaining)/(double) totalSectors) - interval;
				 
				 [[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
			}
			
			++iterations;
		}
		
	}
	
	@finally {
		struct stat			sourceStat;
		NSException			*exception;

		free(buffer);
		free(audioBuffer);
		free(c2Buffer);
		
		// Delete temporary files
		for(i = 0; i < [rips count]; ++i) {
			rip = [rips objectAtIndex:i];
			if(0 == stat([[rip filename] fileSystemRepresentation], &sourceStat) && -1 == unlink([[rip filename] fileSystemRepresentation])) {
				exception = [NSException exceptionWithName:@"IOException"
													reason:NSLocalizedStringFromTable(@"Unable to delete the temporary file.", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}	
		}
		
		if(0 == stat([[masterRip filename] fileSystemRepresentation], &sourceStat) && -1 == unlink([[masterRip filename] fileSystemRepresentation])) {
			exception = [NSException exceptionWithName:@"IOException"
												 reason:NSLocalizedStringFromTable(@"Unable to delete the temporary file.", @"Exceptions", @"") 
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
	int					intResult;
	
	@try {
		tmpDir = [[[[[self delegate] taskInfo] settings] objectForKey:@"temporaryDirectory"] fileSystemRepresentation];
		if(nil == tmpDir) {
			tmpDir = [NSTemporaryDirectory() fileSystemRepresentation];
		}
		
		ValidateAndCreateDirectory([NSString stringWithCString:tmpDir encoding:NSASCIIStringEncoding]);
		
		tmpDirLen	= strlen(tmpDir);
		path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
		NSAssert(NULL != path, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		memcpy(path, tmpDir, tmpDirLen);
		memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
		path[tmpDirLen + patternLen] = '\0';
		
		fd = mkstemps(path, strlen(TEMPFILE_SUFFIX));
		NSAssert(-1 != fd, NSLocalizedStringFromTable(@"Unable to create a temporary file.", @"Exceptions", @""));
		
		result = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
	}
	
	@finally {
		free(path);
		
		// And close it
		if(-1 != fd) {
			intResult = close(fd);
			NSAssert(-1 != intResult, NSLocalizedStringFromTable(@"Unable to close the temporary file.", @"Exceptions", @""));
		}
	}
	
	return (nil != result ? [[result retain] autorelease] : nil);
}

@end
