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

#import "FreeDBMatch.h"

@implementation FreeDBMatch

+ (id) createFromFreeDBDisc:(cddb_disc_t *)disc
{
	FreeDBMatch *result = [[[FreeDBMatch alloc] init] autorelease];
	
	[result setValue:[NSString stringWithCString:cddb_disc_get_artist(disc)] forKey:@"artist"];
	[result setValue:[NSString stringWithCString:cddb_disc_get_title(disc)] forKey:@"title"];
	[result setValue:[NSNumber numberWithUnsignedInt:cddb_disc_get_year(disc)] forKey:@"year"];
	[result setValue:[NSString stringWithCString:cddb_disc_get_genre(disc)] forKey:@"genre"];
	[result setValue:[NSNumber numberWithInt:cddb_disc_get_category(disc)] forKey:@"category"];
	[result setValue:[NSNumber numberWithUnsignedInt:cddb_disc_get_discid(disc)] forKey:@"discid"];
	
	return result;
}

@end
