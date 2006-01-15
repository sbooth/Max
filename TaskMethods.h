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

#define MAX_DO_POLL_FREQUENCY 250

#import <Cocoa/Cocoa.h>

@protocol TaskMethods

- (NSDate *)		getStartTime;
- (NSDate *)		getEndTime;

- (void)			setStartTime:(NSDate *)startTime;
- (void)			setEndTime:(NSDate *)endTime;

- (BOOL)			started;
- (BOOL)			completed;
- (BOOL)			stopped;

- (void)			setStarted;
- (void)			setCompleted;
- (void)			setStopped;

- (double)			percentComplete;
- (void)			setPercentComplete:(double)percentComplete;

- (BOOL)			shouldStop;
- (void)			setShouldStop;

- (NSString *)		getTimeRemaining;
- (void)			setTimeRemaining:(NSString *)timeRemaining;

- (void)			updateProgress:(double)percentComplete timeRemaining:(NSString *)timeRemaining;

- (NSString *)		getInputType;
- (void)			setInputType:(NSString *)inputType;

- (NSString *)		getOutputType;
- (void)			setOutputType:(NSString *)outputType;

@end
