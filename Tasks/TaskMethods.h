/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import <Cocoa/Cocoa.h>
#import "TaskInfo.h"

// The number of iterations a task should run between calls to its delegate
#define MAX_DO_POLL_FREQUENCY 300

// The protocol exposed to Encoders/Rippers running in separate threads
@protocol TaskMethods

- (TaskInfo *)		taskInfo;
- (void)			setTaskInfo:(TaskInfo *)taskInfo;

- (NSDate *)		startTime;
- (void)			setStartTime:(NSDate *)startTime;

- (NSDate *)		endTime;
- (void)			setEndTime:(NSDate *)endTime;

- (BOOL)			started;
- (void)			setStarted:(BOOL)started;

- (BOOL)			completed;
- (void)			setCompleted:(BOOL)completed;

- (BOOL)			stopped;
- (void)			setStopped:(BOOL)stopped;

- (float)			percentComplete;
- (void)			setPercentComplete:(float)percentComplete;

- (BOOL)			shouldStop;
- (void)			setShouldStop:(BOOL)shouldStop;

- (NSUInteger)		secondsRemaining;
- (void)			setSecondsRemaining:(NSUInteger)secondsRemaining;

- (void)			updateProgress:(float)percentComplete secondsRemaining:(NSUInteger)secondsRemaining;

- (NSException *)	exception;
- (void)			setException:(NSException *)exception;

@end
