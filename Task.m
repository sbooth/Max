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
		
		_startTime			= nil;
		_endTime			= nil;
		
		_started			= NO;
		_completed			= NO;
		_stopped			= NO;
		
		_shouldStop			= NO;
		
		_percentComplete	= 0.0;

		_timeRemaining		= nil;
		
		_inputFormat		= nil;
		_outputFormat		= nil;
		
		_exception			= nil;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_startTime release];
	[_endTime release];
	[_timeRemaining release];
	[_inputFormat release];
	[_outputFormat release];
	[_exception release];
	
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
- (NSString *)		outputFormat								{ return _outputFormat; }

- (NSException *)	exception									{ return _exception; }

- (void) setStartTime:(NSDate *)startTime						{ [_startTime release]; _startTime = [startTime retain]; }
- (void) setEndTime:(NSDate *)endTime							{ [_endTime release]; _endTime = [endTime retain]; }

- (void) setStarted												{ [self setPercentComplete:0.0]; _started = YES; }
- (void) setCompleted											{  [self setPercentComplete:100.0]; _completed = YES; }

- (void) setStopped												{ _stopped  = YES; }

- (void) setPercentComplete:(double)percentComplete				{ _percentComplete = percentComplete; }

- (void) setShouldStop											{ _shouldStop = YES; }

- (void) setTimeRemaining:(NSString *)timeRemaining				{ [_timeRemaining release]; _timeRemaining = [timeRemaining retain]; }

- (void) setInputFormat:(NSString *)inputFormat					{ [_inputFormat release]; _inputFormat = [inputFormat retain]; }

- (void) setOutputFormat:(NSString *)outputFormat				{ [_outputFormat release]; _outputFormat = [outputFormat retain]; }

- (void) setException:(NSException *)exception					{ [_exception release]; _exception = [exception retain]; }

- (void) updateProgress:(double)percentComplete timeRemaining:(NSString *)timeRemaining
{
	[self setPercentComplete:percentComplete];
	[self setTimeRemaining:timeRemaining];
}

@end
