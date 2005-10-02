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

#import "Genres.h"

// ID3 genres + WinAmp extensions
static Genres *sharedGenres = nil;

@implementation Genres

- (id) init
{
	if(self = [super init]) {
		_genres = [NSArray arrayWithObjects:
			@"Blues",
			@"Classic Rock",
			@"Country",
			@"Dance",
			@"Disco",
			@"Funk",
			@"Grunge",
			@"Hip-Hop",
			@"Jazz",
			@"Metal",
			@"New Age",
			@"Oldies",
			@"Other",
			@"Pop",
			@"R&B",
			@"Rap",
			@"Reggae",
			@"Rock",
			@"Techno",
			@"Industrial",
			@"Alternative",
			@"Ska",
			@"Death metal",
			@"Pranks",
			@"Soundtrack",
			@"Euro-Techno",
			@"Ambient",
			@"Trip-hop",
			@"Vocal",
			@"Jazz+Funk",
			@"Fusion",
			@"Trance",
			@"Classical",
			@"Instrumental",
			@"Acid",
			@"House",
			@"Game",
			@"Sound Clip",
			@"Gospel",
			@"Noise",
			@"Alt. Rock",
			@"Bass",
			@"Soul",
			@"Punk",
			@"Space",
			@"Meditative",
			@"Instrumental pop",
			@"Instrumental rock",
			@"Ethnic",
			@"Gothic",
			@"Darkwave",
			@"Techno-Industrial",
			@"Electronic",
			@"Pop-Folk",
			@"Eurodance",
			@"Dream",
			@"Southern Rock",
			@"Comedy",
			@"Cult",
			@"Gangsta",
			@"Top 40",
			@"Christian Rap",
			@"Pop/Funk",
			@"Jungle",
			@"Native American",
			@"Cabaret",
			@"New Wave",
			@"Psychedelic",
			@"Rave",
			@"Showtunes",
			@"Trailer",
			@"Lo-Fi",
			@"Tribal",
			@"Acid Punk",
			@"Acid Jazz",
			@"Polka",
			@"Retro",
			@"Musical",
			@"Rock & Roll",
			@"Hard Rock",
			@"Folk",
			@"Folk-Rock",
			@"National Folk",
			@"Swing",
			@"Fast Fusion",
			@"Bebob",
			@"Latin",
			@"Revival",
			@"Celtic",
			@"Bluegrass",
			@"Avantgarde",
			@"Gothic Rock",
			@"Progressive Rock",
			@"Psychedelic Rock",
			@"Symphonic Rock",
			@"Slow Rock",
			@"Big Band",
			@"Chorus",
			@"Easy Listening",
			@"Acoustic",
			@"Humour",
			@"Speech",
			@"Chanson",
			@"Opera",
			@"Chamber Music",
			@"Sonata",
			@"Symphony",
			@"Booty Bass",
			@"Primus",
			@"Porn Groove",
			@"Satire",
			@"Slow Jam",
			@"Club",
			@"Tango",
			@"Samba",
			@"Folklore",
			@"Ballad",
			@"Power Ballad",
			@"Rhythmic Soul",
			@"Freestyle",
			@"Duet",
			@"Punk Rock",
			@"Drum Solo",
			@"A cappella",
			@"Euro-House",
			@"Dance Hall",
			@"Goa",
			@"Drum & Bass",
			@"Club-House",
			@"Hardcore",
			@"Terror",
			@"Indie",
			@"BritPop",
			@"Negerpunk",
			@"Polsk Punk",
			@"Beat",
			@"Christian gangsta rap",
			@"Heavy Metal",
			@"Black Metal",
			@"Crossover",
			@"Contemporary Christian",
			@"Christian Rock",
			@"Merengue",
			@"Salsa",
			@"Thrash Metal",
			@"Anime",
			@"JPop",
			@"Synthpop",
			nil
			];
		_genres = [[_genres sortedArrayUsingSelector:@selector(compare:)] retain];
	}
	return self;
}

+ (NSArray *) sharedGenres
{
	@synchronized(self) {
		if(nil == sharedGenres) {
			sharedGenres = [[[self alloc] init] autorelease];
		}
	}
	return [sharedGenres valueForKey:@"genres"];
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedGenres) {
            return [super allocWithZone:zone];
        }
    }
    return sharedGenres;
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

@end
