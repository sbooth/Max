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

#import "EncoderController.h"
#import "RipperTask.h"
#import "PCMGeneratingTask.h"
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "CoreAudioEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "MonkeysAudioEncoderTask.h"
#import "SpeexEncoderTask.h"
#import "WavPackEncoderTask.h"
#import "LogController.h"
#import "RipperController.h"
#import "ConverterController.h"
#import "IOException.h"
#import "MissingResourceException.h"

#import <Growl/GrowlApplicationBridge.h>
#include <AudioToolbox/AudioFile.h>
#include <sndfile/sndfile.h>

#include <Carbon/Carbon.h>

#include <sys/param.h>		// statfs
#include <sys/mount.h>

static EncoderController *sharedController = nil;

@interface ConverterController (Private)
- (void)	spawnThreads;
@end

@interface EncoderController (Private)
- (void)	updateFreeSpace:(NSTimer *)theTimer;
- (void)	runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task userInfo:(NSDictionary *)userInfo;
- (void)	addTask:(EncoderTask *)task;
- (void)	removeTask:(EncoderTask *)task;
- (void)	spawnThreads;
- (void)	addFileToiTunesLibrary:(NSString *)filename metadata:(AudioMetadata *)metadata;
@end

@implementation EncoderController

+ (EncoderController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController) {
			sharedController = [[self alloc] init];
		}
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            return [super allocWithZone:zone];
        }
    }
    return sharedController;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (id) init
{
	if((self = [super initWithWindowNibName:@"Encoder"])) {
		
		_timer		= [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateFreeSpace:) userInfo:nil repeats:YES];
		_tasks		= [[NSMutableArray arrayWithCapacity:50] retain];
		_freeze		= NO;

		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_timer invalidate];
	[_tasks release];

	[super dealloc];
}

- (void) awakeFromNib
{
	[_taskTable setAutosaveTableColumns:YES];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Encoder"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) updateFreeSpace:(NSTimer *)theTimer
{
	struct statfs			buf;
	unsigned long long		bytesFree;
	long double				freeSpace;
	unsigned				divisions;
	
	if(-1 == statfs([[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] fileSystemRepresentation], &buf)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get file system statistics.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	bytesFree	= (unsigned long long) buf.f_bsize * (unsigned long long) buf.f_bfree;
	freeSpace	= (long double) bytesFree;
	divisions	= 0;
	
	while(1024 < freeSpace) {
		freeSpace /= 1024;
		++divisions;
	}
	
	switch(divisions) {
		case 0:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f B", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 1:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f KB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 2:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f MB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 3:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f GB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 4:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f TB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 5:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f PB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
	}
}

#pragma mark Functionality

- (void) runEncodersForTask:(PCMGeneratingTask *)task
{
	NSArray			*outputFormats		= [[task userInfo] objectForKey:@"encoders"];
	NSDictionary	*format				= nil;
	unsigned		i					= 0;
	
	for(i = 0; i < [outputFormats count]; ++i) {
		format = [outputFormats objectAtIndex:i];
						
		switch([[format objectForKey:@"component"] intValue]) {
			
			case kComponentCoreAudio:
				[self runEncoder:[CoreAudioEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;

			case kComponentLibsndfile:
				[self runEncoder:[LibsndfileEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
			
			case kComponentFLAC:
				[self runEncoder:[FLACEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentOggFLAC:
				[self runEncoder:[OggFLACEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentWavPack:
				[self runEncoder:[WavPackEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentMonkeysAudio:
				[self runEncoder:[MonkeysAudioEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentOggVorbis:
				[self runEncoder:[OggVorbisEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentMP3:
				[self runEncoder:[MPEGEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			case kComponentSpeex:
				[self runEncoder:[SpeexEncoderTask class] forTask:task userInfo:[format objectForKey:@"userInfo"]];
				break;
				
			default:
				NSLog(@"Unknown component: %@", [format objectForKey:@"component"]);
				break;
		}
		
	}
}

- (void) runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task userInfo:(NSDictionary *)userInfo
{
	// Create the encoder (relies on each subclass having the same method signature)
	EncoderTask *encoderTask = [[encoderClass alloc] initWithTask:task];
	
	if([task isKindOfClass:[RipperTask class]]) {
		[encoderTask setTracks:[(RipperTask *)task valueForKey:@"tracks"]];
	}
	
	// Set output directory
	[encoderTask setOutputDirectory:[[task userInfo] objectForKey:@"outputDirectory"]];

	[encoderTask setOverwriteExistingFiles:[[[task userInfo] objectForKey:@"overwriteExistingFiles"] boolValue]];
	
	// Pass the encoding configuration parameters
	[encoderTask setUserInfo:userInfo];
	
	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[self addTask:[encoderTask autorelease]];
	[self spawnThreads];
}

- (BOOL) documentHasEncoderTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	EncoderTask		*current;
	
	enumerator = [[_tasksController arrangedObjects] objectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			return YES;
		}
	}
	
	return NO;
}

- (void) stopEncoderTasksForDocument:(CompactDiscDocument *)document
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			[current stop];
		}
	}
	_freeze = NO;
}

#pragma Action Methods

- (IBAction) stopSelectedTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController selectedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

- (IBAction) stopAllTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

#pragma mark Callbacks

- (void) encoderTaskDidStart:(EncoderTask *)task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormat];
	NSString	*settings		= [task settings];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode started for %@ [%@]", @"Log", @""), trackName, type]];
	if(nil != settings) {
		[LogController logMessage:settings];
	}
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode started", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encoderTaskDidStop:(EncoderTask *)task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode stopped for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode stopped", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
}

- (void) encoderTaskDidComplete:(EncoderTask *)task
{
	NSDate			*startTime		= [task startTime];
	NSDate			*endTime		= [task endTime];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
	NSString		*type			= [task outputFormat];
	BOOL			justNotified	= NO;
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode completed for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type], [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
	
	if(0 != [task countOfTracks] && NO == [[[task objectInTracksAtIndex:0] document] ripInProgress] && NO == [[[task objectInTracksAtIndex:0] document] encodeInProgress]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Disc encoding completed", @"Log", @"")
									description:[NSString stringWithFormat:NSLocalizedStringFromTable(@"All encoding tasks completed for %@", @"Log", @""), [[task metadata] albumTitle]]
							   notificationName:@"Disc encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		justNotified = YES;
	}

	// No more tasks in any queues
	if(NO == [self hasTasks] && NO == [[RipperController sharedController] hasTasks] && NO == [[ConverterController sharedController] hasTasks]) {

		// Bounce dock icon if we're not the active application
		if(NO == [[NSApplication sharedApplication] isActive]) {
			[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];			
		}
		
		// Try to avoid Growl floods
		if(NO == justNotified) {
			[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encoding completed", @"Log", @"")
										description:NSLocalizedStringFromTable(@"All encoding tasks completed", @"Log", @"")
								   notificationName:@"Encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		}
	}

	
	if(0 != [task countOfTracks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"] && NO == [[[task objectInTracksAtIndex:0] document] ripInProgress] && NO == [[[task objectInTracksAtIndex:0] document] encodeInProgress]) {
		CompactDiscDocument *doc = [[task objectInTracksAtIndex:0] document];
		[doc saveDocument:self];
		[[doc windowForSheet] performClose:self];
	}

	// Add files to iTunes if desired
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyAddToiTunes"]) {
	
		// File already contains metadata, just use the playlist
		if([task isKindOfClass:[MPEGEncoderTask class]] || ([task isKindOfClass:[CoreAudioEncoderTask class]] && kAudioFileM4AType == [(CoreAudioEncoderTask *)task fileType])) {
			AudioMetadata	*metadata = [[[AudioMetadata alloc] init] autorelease];
			
			[metadata setPlaylist:[[task metadata] playlist]];
			[self addFileToiTunesLibrary:[task outputFilename] metadata:metadata];
		}
		// Need to set metadata using AppleScript
		else if(([task isKindOfClass:[CoreAudioEncoderTask class]] && (kAudioFileAIFFType == [(CoreAudioEncoderTask *)task fileType] || kAudioFileWAVEType == [(CoreAudioEncoderTask *)task fileType])) ||
				([task isKindOfClass:[LibsndfileEncoderTask class]] && (SF_FORMAT_AIFF == ([(LibsndfileEncoderTask *)task format] & SF_FORMAT_TYPEMASK) || SF_FORMAT_WAV == ([(LibsndfileEncoderTask *)task format] & SF_FORMAT_TYPEMASK)))) {
			[self addFileToiTunesLibrary:[task outputFilename] metadata:[task metadata]];
		}
	}
}

#pragma mark Task Management

- (unsigned)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }
- (void)		addTask:(EncoderTask *)task				{ [_tasksController addObject:task]; }

- (void) removeTask:(EncoderTask *)task
{
	[_tasksController removeObject:task];
	
	// Hide the window if no more tasks
	if(NO == [self hasTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] performClose:self];
	}
}

- (void) spawnThreads
{
	unsigned	maxThreads		= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
	unsigned	i;
	unsigned	limit;
	
	if(0 == [_tasks count] || _freeze) {
		return;
	}
	
	limit = (maxThreads < [_tasks count] ? maxThreads : [_tasks count]);
	
	// Start encoding the next track(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[_tasks objectAtIndex:i] started]) {
			[[_tasks objectAtIndex:i] run];
		}	
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"balanceConverters"]) {
		[[ConverterController sharedController] spawnThreads];
	}
}

- (void) addFileToiTunesLibrary:(NSString *)filename metadata:(AudioMetadata *)metadata
{
	NSDictionary				*errors				= [NSDictionary dictionary];
	NSString					*path				= nil;
	NSAppleScript				*appleScript		= nil;
	NSAppleEventDescriptor		*parameters			= nil;
	ProcessSerialNumber			psn					= { 0, kCurrentProcess };
	NSAppleEventDescriptor		*target				= nil;
	NSAppleEventDescriptor		*handler			= nil;
	NSAppleEventDescriptor		*event				= nil;
	NSAppleEventDescriptor		*result				= nil;
	NSString					*artist				= nil;
	NSString					*composer			= nil;
	NSString					*genre				= nil;
	unsigned					year				= 0;
	NSString					*comment			= nil;
	
	
	@try {
		path = [[NSBundle mainBundle] pathForResource:@"Add to iTunes Library" ofType:@"scpt"];
		if(nil == path) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"Add to iTunes Library.scpt" forKey:@"filename"]];
		}

		appleScript = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&errors] autorelease];
		if(nil == appleScript) {
			@throw [NSException exceptionWithName:@"AppleScriptError" reason:@"Unable to setup AppleScript." userInfo:errors];
		}
		
		// Metadata fallback
		artist		= (nil == [metadata trackArtist] ? [metadata albumArtist] : [metadata trackArtist]);
		composer	= (nil == [metadata trackComposer] ? [metadata albumComposer] : [metadata trackComposer]);
		genre		= (nil == [metadata trackGenre] ? [metadata albumGenre] : [metadata trackGenre]);
		year		= (0 == [metadata trackYear] ? [metadata albumYear] : [metadata trackYear]);
		comment		= (nil == [metadata albumComment] ? [metadata trackComment] : (nil == [metadata trackComment] ? [metadata albumComment] : [NSString stringWithFormat:@"%@\n%@", [metadata trackComment], [metadata albumComment]]));
		
		parameters		= [NSAppleEventDescriptor listDescriptor];
		
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:filename]															atIndex:1];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata playlist] ? @"" : [metadata playlist])]			atIndex:2];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata albumTitle] ? @"" : [metadata albumTitle])]		atIndex:3];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == artist ? @"" : artist)]									atIndex:4];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == composer ? @"" : composer)]								atIndex:5];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == genre ? @"" : genre)]										atIndex:6];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:year]																atIndex:7];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == comment ? @"" : comment)]									atIndex:8];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata trackTitle] ? @"" : [metadata trackTitle])]		atIndex:9];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata trackNumber]]											atIndex:10];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata trackTotal]]												atIndex:11];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithBoolean:[metadata compilation]]											atIndex:12];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata discNumber]]												atIndex:13];
		[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata discTotal]]												atIndex:14];
		
		target			= [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(psn)];
		handler			= [NSAppleEventDescriptor descriptorWithString:[@"add_file_to_itunes_library" lowercaseString]];
		event			= [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

		[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
		[event setParamDescriptor:parameters forKeyword:keyDirectObject];

		// Call the event in AppleScript
		result = [appleScript executeAppleEvent:event error:&errors];
		if(nil == result) {
			@throw [NSException exceptionWithName:@"AppleScriptError" reason:[errors objectForKey:NSAppleScriptErrorMessage] userInfo:errors];
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while adding the file \"%@\" to the iTunes library.", @"Exceptions", @""), [filename lastPathComponent]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

@end
