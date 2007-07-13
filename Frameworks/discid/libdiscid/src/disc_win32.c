/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Portions Copyright (C) 2000 Emusic.com
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

     $Id: disc_win32.c 8506 2006-09-30 19:02:57Z luks $

----------------------------------------------------------------------------*/

#include <windows.h>
#include <mmsystem.h>
#include <string.h>
#include <stdio.h>
#ifdef _MSC_VER
#define snprintf _snprintf
#endif

#include "discid/discid_private.h"

#define MB_DEFAULT_DEVICE	"cdaudio"

char *mb_disc_get_default_device_unportable(void) {
	return MB_DEFAULT_DEVICE;
} 

int mb_disc_read_unportable(mb_disc_private *disc, const char *device) {
	int	i, ret, last_track;
	char mci_command[128];
	char mci_return[128];
	char alias[128], device_str[128], error_msg[256];
	
	if ( strlen(device) == 0 || strcmp(device, "cdaudio") == 0 ) {
		sprintf(device_str, "cdaudio");
	}
	else {
		snprintf(device_str, 128, "%s type cdaudio", device);
	}

	/*
	 * Prepare unique device alias.
	 */
	snprintf(alias, 128, "libdiscid_%u_%u", (unsigned)GetTickCount(),
		(unsigned)GetCurrentThreadId());

	/*
	 * Check number of CD audio devices
	 */
	snprintf(mci_command, 128, "sysinfo cdaudio quantity wait");
	mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
	if ( atoi(mci_return) <= 0 ) {
		snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,
			"no CD audio devices");
		return 0;
	}

	/*
	 * Open specified CD audio device
	 */
	snprintf(mci_command, 128, "open %s shareable alias %s wait",
		device_str,	alias);
	ret = mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
	if ( ret != 0 ) {
		mciGetErrorString(ret, error_msg, 256); 
		snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,
			"cannot open device `%s': %s", device, error_msg);
		return 0;
	}

	/*
	 * Find the numbers of the first track (usually 1) and the last track.
	 */ 
	snprintf(mci_command, 128, "status %s number of tracks wait", alias);
	ret = mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
	if ( ret != 0 ) {
		mciGetErrorString(ret, error_msg, 256); 
		snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,
			"cannot read number of tracks: %s", error_msg);
		return 0;
	}
	
	last_track = atoi(mci_return);
	disc->first_track_num = 1;
	disc->last_track_num = last_track;

	/*
	 * Set time format to MSF (the returned track positions will be in format
	 * mm:ss:ff, where mm is minutes, ss is seconds, and ff is frames).
	 */
	snprintf(mci_command, 128, "set %s time format msf wait", alias);
	ret = mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
	if ( ret != 0 ) {
		mciGetErrorString(ret, error_msg, 256); 
		snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,
			"cannot set time format: %s", error_msg);
		return 0;
	}
	
	/*
	 * Read positions for all tracks in the CD.
	 */
	for (i = 1; i <= last_track; i++) {
		snprintf(mci_command, 128, "status %s position track %d wait",
			alias, i);
		mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
		disc->track_offsets[i] =
			atoi(mci_return + 0) * 4500 +
			atoi(mci_return + 3) * 75 +
			atoi(mci_return + 6);
	}
	
	/*
	 * Read length of the last track and calculate length of the whole CD.
	 */
	snprintf(mci_command, 128, "status %s length track %d wait",
		alias, last_track);
	mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);
	disc->track_offsets[0] =
		atoi(mci_return + 0) * 4500 +
		atoi(mci_return + 3) * 75 +
		atoi(mci_return + 6) +
		disc->track_offsets[last_track] + 1;
			
	/*
	 * Close the CD audio device
	 */
	snprintf(mci_command, 128, "close %s wait", alias);
	mciSendString(mci_command, mci_return, sizeof(mci_return), NULL);

	return 1;
}

/* EOF */
