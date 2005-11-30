/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "Ripper.h"
#import "Track.h"
#import "CompactDiscDocument.h"
#import "CompactDisc.h"
#import "MallocException.h"
#import "StopException.h"
#import "IOException.h"
#import "MissingResourceException.h"

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close

static char *callback_strings[15]={"wrote",
	"finished",
	"read",
	"verify",
	"jitter",
	"correction",
	"scratch",
	"scratch repair",
	"skip",
	"drift",
	"backoff",
	"overlap",
	"dropped",
	"duped",
	"transport error"};

static void 
callback(long inpos, int function)
{
	/*
	 
	 (== PROGRESS == [--+!---x-------------->           | 007218 01 ] == :-) . ==) 
	 
	 */
	
	int graph=30;
	char buffer[256];
	static long c_sector=0,v_sector=0;
	static char dispcache[30]="                              ";
	static int last=0;
	static long lasttime=0;
	long sector,osector=0;
	struct timeval thistime;
	static char heartbeat=' ';
	int position=0,aheadposition=0;
	static int overlap=0;
	static int printit=-1;
	
	static int slevel=0;
	static int slast=0;
	static int stimeout=0;
	char *smilie="= :-)";
	
//	if(callscript)
		fprintf(stderr,"##: %d [%s] @ %ld\n",
				function,(function>=-2&&function<=13?callback_strings[function+2]:
						  ""),inpos);
#if 0	
	if(!quiet){
		long test;
		osector=inpos;
		sector=inpos/CD_FRAMEWORDS;
		
		if(printit==-1){
			if(isatty(STDERR_FILENO)){
				printit=1;
			}else{
				printit=0;
			}
		}
		
		if(printit==1){  /* else don't bother; it's probably being 
			redirected */
			position=((float)(sector-callbegin)/
					  (callend-callbegin))*graph;
			
			aheadposition=((float)(c_sector-callbegin)/
						   (callend-callbegin))*graph;
			
			if(function==-2){
				v_sector=sector;
				return;
			}
			if(function==-1){
				last=8;
				heartbeat='*';
				slevel=0;
				v_sector=sector;
			}else
				if(position<graph && position>=0)
					switch(function){
						case PARANOIA_CB_VERIFY:
							if(stimeout>=30){
								if(overlap>CD_FRAMEWORDS)
									slevel=2;
								else
									slevel=1;
							}
							break;
						case PARANOIA_CB_READ:
							if(sector>c_sector)c_sector=sector;
							break;
							
						case PARANOIA_CB_FIXUP_EDGE:
							if(stimeout>=5){
								if(overlap>CD_FRAMEWORDS)
									slevel=2;
								else
									slevel=1;
							}
							if(dispcache[position]==' ') 
								dispcache[position]='-';
							break;
						case PARANOIA_CB_FIXUP_ATOM:
							if(slevel<3 || stimeout>5)slevel=3;
							if(dispcache[position]==' ' ||
							   dispcache[position]=='-')
								dispcache[position]='+';
								break;
						case PARANOIA_CB_READERR:
							slevel=6;
							if(dispcache[position]!='V')
								dispcache[position]='e';
								break;
						case PARANOIA_CB_SKIP:
							slevel=8;
							dispcache[position]='V';
							break;
						case PARANOIA_CB_OVERLAP:
							overlap=osector;
							break;
						case PARANOIA_CB_SCRATCH:
							slevel=7;
							break;
						case PARANOIA_CB_DRIFT:
							if(slevel<4 || stimeout>5)slevel=4;
							break;
						case PARANOIA_CB_FIXUP_DROPPED:
						case PARANOIA_CB_FIXUP_DUPED:
							slevel=5;
							if(dispcache[position]==' ' ||
							   dispcache[position]=='-' ||
							   dispcache[position]=='+')
								dispcache[position]='!';
								break;
					}
						
						switch(slevel){
							case 0:  /* finished, or no jitter */
								if(skipped_flag)
									smilie=" 8-X";
								else
									smilie=" :^D";
								break;
							case 1:  /* normal.  no atom, low jitter */
								smilie=" :-)";
								break;
							case 2:  /* normal, overlap > 1 */
								smilie=" :-|";
								break; 
							case 4:  /* drift */
								smilie=" :-/";
									break;
								case 3:  /* unreported loss of streaming */
									smilie=" :-P";
									break;
								case 5:  /* dropped/duped bytes */
									smilie=" 8-|";
									break;
								case 6:  /* scsi error */
									smilie=" :-0";
									break;
								case 7:  /* scratch */
									smilie=" :-(";
									break;
								case 8:  /* skip */
									smilie=" ;-(";
									skipped_flag=1;
									break;
									
						}
						
						gettimeofday(&thistime,NULL);
			test=thistime.tv_sec*10+thistime.tv_usec/100000;
			
			if(lasttime!=test || function==-1 || slast!=slevel){
				if(lasttime!=test || function==-1){
					last++;
					lasttime=test;
					if(last>7)last=0;
					stimeout++;
					switch(last){
						case 0:
							heartbeat=' ';
							break;
						case 1:case 7:
							heartbeat='.';
							break;
						case 2:case 6:
							heartbeat='o';
							break;
						case 3:case 5:  
							heartbeat='0';
							break;
						case 4:
							heartbeat='O';
							break;
					}
					if(function==-1)
						heartbeat='*';
					
				}
				if(slast!=slevel){
					stimeout=0;
				}
				slast=slevel;
				
				if(abort_on_skip && skipped_flag && function !=-1){
					sprintf(buffer,
							"\r (== PROGRESS == [%s| %06ld %02d ] ==%s %c ==)   ",
							"  ...aborting; please wait... ",
							v_sector,overlap/CD_FRAMEWORDS,smilie,heartbeat);
				}else{
					if(v_sector==0)
						sprintf(buffer,
								"\r (== PROGRESS == [%s| ...... %02d ] ==%s %c ==)   ",
								dispcache,overlap/CD_FRAMEWORDS,smilie,heartbeat);
					
					else
						sprintf(buffer,
								"\r (== PROGRESS == [%s| %06ld %02d ] ==%s %c ==)   ",
								dispcache,v_sector,overlap/CD_FRAMEWORDS,smilie,heartbeat);
					
					if(aheadposition>=0 && aheadposition<graph && !(function==-1))
						buffer[aheadposition+19]='>';
				}
				
				fprintf(stderr,buffer);
			}
		}
	}
	
	/* clear the indicator for next batch */
	if(function==-1)
		memset(dispcache,' ',graph);
#endif
}

// Tag values for NSPopupButton
enum {
	PARANOIA_LEVEL_FULL					= 0,
	PARANOIA_LEVEL_OVERLAP_CHECKING		= 1
};

@implementation Ripper

+ (void) initialize
{
	NSString				*paranoiaDefaultsValuesPath;
    NSDictionary			*paranoiaDefaultsValuesDictionary;
    
	@try {
		paranoiaDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ParanoiaDefaults" ofType:@"plist"];
		if(nil == paranoiaDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load ParanoiaDefaults.plist." userInfo:nil];
		}
		paranoiaDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:paranoiaDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:paranoiaDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Ripper::init called" userInfo:nil];
}

- (id) initWithTrack:(Track *)track
{
	if((self = [super init])) {
		int paranoiaLevel	= 0;
		int paranoiaMode	= PARANOIA_MODE_DISABLE;
		
		_track	= [track retain];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"started"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"completed"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"stopped"];
		
		// Setup cdparanoia
		_drive		= [[[_track getDiscDocument] getDisc] getDrive];
		_paranoia	= paranoia_init(_drive);

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaEnable"]) {
			paranoiaMode = PARANOIA_MODE_FULL ^ PARANOIA_MODE_NEVERSKIP; 
			
			paranoiaLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaLevel"];
			
			if(PARANOIA_LEVEL_FULL == paranoiaLevel) {
			}
			else if(PARANOIA_LEVEL_OVERLAP_CHECKING == paranoiaLevel) {
				paranoiaMode |= PARANOIA_MODE_OVERLAP;
				paranoiaMode &= ~PARANOIA_MODE_VERIFY;
			}
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaNeverSkip"]) {
				paranoiaMode |= PARANOIA_MODE_NEVERSKIP;
				_maximumRetries = -1;
			}
			else {
				_maximumRetries = [[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaMaximumRetries"];
			}
		}
		else {
			paranoiaMode = PARANOIA_MODE_DISABLE;
		}

		paranoia_modeset(_paranoia, paranoiaMode);
		
		// Determine the size of the track we are ripping
		_firstSector	= [[_track valueForKey:@"firstSector"] unsignedLongValue];
		_lastSector		= [[_track valueForKey:@"lastSector"] unsignedLongValue];
		
		// Go to the track's first sector in preparation for reading
		long where = paranoia_seek(_paranoia, _firstSector, SEEK_SET);   	    
		if(-1 == where) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			paranoia_free(_paranoia);
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	paranoia_free(_paranoia);
	
	[_track release];
	
	[super dealloc];
}

- (void) requestStop
{
	@synchronized(self) {
		if([_started boolValue]) {
			_shouldStop = [NSNumber numberWithBool:YES];			
		}
		else {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		}
	}
}

- (void) ripToFile:(int) file
{
	unsigned long		cursor				= _firstSector;
	int16_t				*buf				= NULL;
	NSDate				*startTime			= [NSDate date];
	unsigned long		totalSectors		= _lastSector - _firstSector + 1;
	unsigned long		sectorsToRead		= totalSectors;
	
	// Tell our owner we are starting
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	while(cursor <= _lastSector) {

		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk
		buf = paranoia_read_limited(_paranoia, NULL/*callback*/, (-1 == _maximumRetries ? 20 : _maximumRetries));
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];			
		}
				
		// Update status
		sectorsToRead--;
		if(0 == sectorsToRead % 10) {
			[self setValue:[NSNumber numberWithDouble:((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0] forKey:@"percentComplete"];
			NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
			unsigned int timeRemaining = interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
			[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
		}
		
		// Write data to file
		if(-1 == write(file, buf, CD_FRAMESIZE_RAW)) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Advance cursor
		++cursor;
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
}

@end
