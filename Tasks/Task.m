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

#import "Task.h"

@interface Task (Private)
- (void)		deleteOutputFile;
@end

@implementation Task

+ (void) initialize
{
	[self exposeBinding:@"startTime"];
	[self exposeBinding:@"endTime"];
	[self exposeBinding:@"percentComplete"];
	[self exposeBinding:@"secondsRemaining"];
}

- (id) init
{
	if((self = [super init])) {
		_secondsRemaining = UINT_MAX;
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	if([self shouldDeleteOutputFile]) {
		[self deleteOutputFile];
	}

	[_taskInfo release];		_taskInfo = nil;
	[_startTime release];		_startTime = nil;
	[_endTime release];			_endTime = nil;
	[_phase release];			_phase = nil;
	[_exception release];		_exception = nil;
	[_outputFilename release];	_outputFilename = nil;
	
	[super dealloc];
}

#pragma mark TaskMethods method implementations

- (TaskInfo *)		taskInfo									{ return [[_taskInfo retain] autorelease]; }
- (void)			setTaskInfo:(TaskInfo *)taskInfo			{ [_taskInfo release]; _taskInfo = [taskInfo retain]; }

- (NSDate *)		startTime									{ return [[_startTime retain] autorelease]; }
- (void)			setStartTime:(NSDate *)startTime			{ [_startTime release]; _startTime = [startTime retain]; }

- (NSDate *)		endTime										{ return [[_endTime retain] autorelease]; }
- (void)			setEndTime:(NSDate *)endTime				{ [_endTime release]; _endTime = [endTime retain]; }

- (BOOL)			started										{ return _started; }
- (void)			setStarted:(BOOL)started					{ _started = started; }

- (BOOL)			completed									{ return _completed; }
- (void)			setCompleted:(BOOL)completed				{ _completed = completed; }

- (BOOL)			stopped										{ return _stopped; }
- (void)			setStopped:(BOOL)stopped					{ _stopped = stopped; }

- (float)			percentComplete								{ return _percentComplete; }
- (void)			setPercentComplete:(float)percentComplete	{ _percentComplete = percentComplete; }

- (BOOL)			shouldStop									{ return _shouldStop; }
- (void)			setShouldStop:(BOOL)shouldStop				{ _shouldStop = shouldStop; }

- (NSUInteger)		secondsRemaining							{ return _secondsRemaining; }
- (void)			setSecondsRemaining:(NSUInteger)secondsRemaining { _secondsRemaining = secondsRemaining; }

- (NSException *)	exception									{ return [[_exception retain] autorelease]; }
- (void)			setException:(NSException *)exception		{ [_exception release]; _exception = [exception retain]; }

- (void)			updateProgress:(float)percentComplete secondsRemaining:(NSUInteger)secondsRemaining
{
	[self setPercentComplete:percentComplete];
	[self setSecondsRemaining:secondsRemaining];
}

#pragma mark Task methods

- (void)			run											{}
- (void)			stop										{}

- (NSString *)		outputFilename								{ return [[_outputFilename retain] autorelease];}
- (void)			setOutputFilename:(NSString *)outputFilename { [_outputFilename release]; _outputFilename = [outputFilename retain]; }

- (BOOL)			shouldDeleteOutputFile						{ return _shouldDeleteOutputFile; }
- (void)			setShouldDeleteOutputFile:(BOOL)shouldDeleteOutputFile { _shouldDeleteOutputFile = shouldDeleteOutputFile; }

@end

@implementation Task (Private)

- (void) deleteOutputFile
{
	if([[NSFileManager defaultManager] fileExistsAtPath:[self outputFilename]]) {
		BOOL			result			= [[NSFileManager defaultManager] removeItemAtPath:[self outputFilename] error:nil];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") );
	}
}

@end
