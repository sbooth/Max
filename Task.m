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

#import "Task.h"

@implementation Task

- (id) init
{
	if((self = [super init])) {
		
		_started			= NO;
		_completed			= NO;
		_stopped			= NO;
		
		_shouldStop			= NO;
		
		_percentComplete	= 0.0;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	if(nil != _startTime) {
		[_startTime release];
	}
	
	if(nil != _endTime) {
		[_endTime release];
	}
	
	if(nil != _timeRemaining) {
		[_timeRemaining release];
	}
	
	if(nil != _inputFormat) {
		[_inputFormat release];
	}

	if(nil != _outputFormat) {
		[_outputFormat release];
	}
	
	if(nil != _exception) {
		[_exception release];
	}
	
	[super dealloc];
}

- (NSDate *)		startTime									{ return _startTime; }
- (NSDate *)		endTime										{ return _endTime; }

- (BOOL)			started										{ return _started; }
- (BOOL)			completed									{ return _completed; }
- (BOOL)			stopped										{ return _stopped; }

- (double)			percentComplete								{ return _percentComplete; }

- (BOOL)			shouldStop									{ return _shouldStop; }

- (NSString *)		timeRemaining								{ return _timeRemaining; }

- (NSString *)		inputFormat									{ return _inputFormat; }
- (NSString *)		outputFormat									{ return _outputFormat; }

- (NSException *)	exception									{ return _exception; }

- (void) setStartTime:(NSDate *)startTime
{ 
	[self willChangeValueForKey:@"startTime"];
	if(nil != _startTime) {
		[_startTime release];
	}
	_startTime = [startTime retain];
	[self didChangeValueForKey:@"startTime"];
}

- (void) setEndTime:(NSDate *)endTime
{ 
	[self willChangeValueForKey:@"endTime"];
	if(nil != _endTime) {
		[_endTime release];
	}
	_endTime = [endTime retain];
	[self didChangeValueForKey:@"endTime"];
}

- (void) setStarted
{
	[self setPercentComplete:0.0];
	
	[self willChangeValueForKey:@"started"];
	_started = YES;
	[self didChangeValueForKey:@"started"];
}
- (void) setCompleted
{ 
	[self setPercentComplete:100.0];
	
	[self willChangeValueForKey:@"completed"];
	_completed = YES;
	[self didChangeValueForKey:@"completed"];
}

- (void) setStopped
{
	[self willChangeValueForKey:@"stopped"];
	_stopped  = YES;
	[self didChangeValueForKey:@"stopped"];
}

- (void) setPercentComplete:(double)percentComplete
{
	[self willChangeValueForKey:@"percentComplete"];
	_percentComplete = percentComplete;
	[self didChangeValueForKey:@"percentComplete"];
}

- (void) setShouldStop
{
	[self willChangeValueForKey:@"shouldStop"];
	_shouldStop = YES;
	[self didChangeValueForKey:@"shouldStop"];
}

- (void) setTimeRemaining:(NSString *)timeRemaining
{
	[self willChangeValueForKey:@"timeRemaining"];
	if(nil != _timeRemaining) {
		[_timeRemaining release];
	}
	_timeRemaining = [timeRemaining retain];
	[self didChangeValueForKey:@"timeRemaining"];
}

- (void) setInputFormat:(NSString *)inputFormat
{
	[self willChangeValueForKey:@"inputFormat"];
	if(nil != _inputFormat) {
		[_inputFormat release];
	}
	_inputFormat = [inputFormat retain];
	[self didChangeValueForKey:@"inputFormat"];
}

- (void) setOutputFormat:(NSString *)outputFormat
{
	[self willChangeValueForKey:@"outputFormat"];
	if(nil != _outputFormat) {
		[_outputFormat release];
	}
	_outputFormat = [outputFormat retain];
	[self didChangeValueForKey:@"outputFormat"];
}

- (void) setException:(NSException *)exception
{
	[self willChangeValueForKey:@"exception"];
	if(nil != _exception) {
		[_exception release];
	}
	_exception = [exception retain];
	[self didChangeValueForKey:@"exception"];
	
	displayExceptionAlert(exception);
}

- (void) updateProgress:(double)percentComplete timeRemaining:(NSString *)timeRemaining
{
	[self setPercentComplete:percentComplete];
	[self setTimeRemaining:timeRemaining];
}

@end
