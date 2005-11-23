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

#import "FreeDBSite.h"

@implementation FreeDBSite

+ (id) createFromFreeDBSite:(const cddb_site_t *)site
{
	const char		*tempString;
	unsigned int	i;
	float			latitude, longitude;
	FreeDBSite		*result;
	
	result = [[[FreeDBSite alloc] init] autorelease];
	
	if(CDDB_ERR_OK == cddb_site_get_address(site, &tempString, &i)) {
		[result setValue:[NSString stringWithCString:tempString] forKey:@"address"];
		[result setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"port"];
	}

	[result setValue:[NSNumber numberWithInt:cddb_site_get_protocol(site)] forKey:@"protocol"];
	
	if(CDDB_ERR_OK == cddb_site_get_description(site, &tempString)) {
		[result setValue:[NSString stringWithCString:tempString] forKey:@"siteDescription"];
	}

	if(CDDB_ERR_OK == cddb_site_get_location(site, &latitude, &longitude)) {
		[result setValue:[NSNumber numberWithFloat:latitude] forKey:@"latitude"];
		[result setValue:[NSNumber numberWithFloat:longitude] forKey:@"longitude"];
	}
	
	return result;
}

@end
