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

#import "Genres.h"

// ID3 genres + WinAmp extensions
static Genres *sharedGenres = nil;

@implementation Genres

- (id) init
{
	if((self = [super init])) {
		_unsortedGenres = [NSArray arrayWithObjects:
			NSLocalizedStringFromTable(@"Blues", @"Genres", @""),
			NSLocalizedStringFromTable(@"Classic Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Country", @"Genres", @""),
			NSLocalizedStringFromTable(@"Dance", @"Genres", @""),
			NSLocalizedStringFromTable(@"Disco", @"Genres", @""),
			NSLocalizedStringFromTable(@"Funk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Grunge", @"Genres", @""),
			NSLocalizedStringFromTable(@"Hip-Hop", @"Genres", @""),
			NSLocalizedStringFromTable(@"Jazz", @"Genres", @""),
			NSLocalizedStringFromTable(@"Metal", @"Genres", @""),
			NSLocalizedStringFromTable(@"New Age", @"Genres", @""),
			NSLocalizedStringFromTable(@"Oldies", @"Genres", @""),
			NSLocalizedStringFromTable(@"Other", @"Genres", @""),
			NSLocalizedStringFromTable(@"Pop", @"Genres", @""),
			NSLocalizedStringFromTable(@"R&B", @"Genres", @""),
			NSLocalizedStringFromTable(@"Rap", @"Genres", @""),
			NSLocalizedStringFromTable(@"Reggae", @"Genres", @""),
			NSLocalizedStringFromTable(@"Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Techno", @"Genres", @""),
			NSLocalizedStringFromTable(@"Industrial", @"Genres", @""),
			NSLocalizedStringFromTable(@"Alternative", @"Genres", @""),
			NSLocalizedStringFromTable(@"Ska", @"Genres", @""),
			NSLocalizedStringFromTable(@"Death metal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Pranks", @"Genres", @""),
			NSLocalizedStringFromTable(@"Soundtrack", @"Genres", @""),
			NSLocalizedStringFromTable(@"Euro-Techno", @"Genres", @""),
			NSLocalizedStringFromTable(@"Ambient", @"Genres", @""),
			NSLocalizedStringFromTable(@"Trip-hop", @"Genres", @""),
			NSLocalizedStringFromTable(@"Vocal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Jazz+Funk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Fusion", @"Genres", @""),
			NSLocalizedStringFromTable(@"Trance", @"Genres", @""),
			NSLocalizedStringFromTable(@"Classical", @"Genres", @""),
			NSLocalizedStringFromTable(@"Instrumental", @"Genres", @""),
			NSLocalizedStringFromTable(@"Acid", @"Genres", @""),
			NSLocalizedStringFromTable(@"House", @"Genres", @""),
			NSLocalizedStringFromTable(@"Game", @"Genres", @""),
			NSLocalizedStringFromTable(@"Sound Clip", @"Genres", @""),
			NSLocalizedStringFromTable(@"Gospel", @"Genres", @""),
			NSLocalizedStringFromTable(@"Noise", @"Genres", @""),
			NSLocalizedStringFromTable(@"Alt. Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Bass", @"Genres", @""),
			NSLocalizedStringFromTable(@"Soul", @"Genres", @""),
			NSLocalizedStringFromTable(@"Punk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Space", @"Genres", @""),
			NSLocalizedStringFromTable(@"Meditative", @"Genres", @""),
			NSLocalizedStringFromTable(@"Instrumental pop", @"Genres", @""),
			NSLocalizedStringFromTable(@"Instrumental rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Ethnic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Gothic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Darkwave", @"Genres", @""),
			NSLocalizedStringFromTable(@"Techno-Industrial", @"Genres", @""),
			NSLocalizedStringFromTable(@"Electronic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Pop-Folk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Eurodance", @"Genres", @""),
			NSLocalizedStringFromTable(@"Dream", @"Genres", @""),
			NSLocalizedStringFromTable(@"Southern Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Comedy", @"Genres", @""),
			NSLocalizedStringFromTable(@"Cult", @"Genres", @""),
			NSLocalizedStringFromTable(@"Gangsta", @"Genres", @""),
			NSLocalizedStringFromTable(@"Top 40", @"Genres", @""),
			NSLocalizedStringFromTable(@"Christian Rap", @"Genres", @""),
			NSLocalizedStringFromTable(@"Pop/Funk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Jungle", @"Genres", @""),
			NSLocalizedStringFromTable(@"Native American", @"Genres", @""),
			NSLocalizedStringFromTable(@"Cabaret", @"Genres", @""),
			NSLocalizedStringFromTable(@"New Wave", @"Genres", @""),
			NSLocalizedStringFromTable(@"Psychedelic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Rave", @"Genres", @""),
			NSLocalizedStringFromTable(@"Showtunes", @"Genres", @""),
			NSLocalizedStringFromTable(@"Trailer", @"Genres", @""),
			NSLocalizedStringFromTable(@"Lo-Fi", @"Genres", @""),
			NSLocalizedStringFromTable(@"Tribal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Acid Punk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Acid Jazz", @"Genres", @""),
			NSLocalizedStringFromTable(@"Polka", @"Genres", @""),
			NSLocalizedStringFromTable(@"Retro", @"Genres", @""),
			NSLocalizedStringFromTable(@"Musical", @"Genres", @""),
			NSLocalizedStringFromTable(@"Rock & Roll", @"Genres", @""),
			NSLocalizedStringFromTable(@"Hard Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Folk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Folk-Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"National Folk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Swing", @"Genres", @""),
			NSLocalizedStringFromTable(@"Fast Fusion", @"Genres", @""),
			NSLocalizedStringFromTable(@"Bebob", @"Genres", @""),
			NSLocalizedStringFromTable(@"Latin", @"Genres", @""),
			NSLocalizedStringFromTable(@"Revival", @"Genres", @""),
			NSLocalizedStringFromTable(@"Celtic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Bluegrass", @"Genres", @""),
			NSLocalizedStringFromTable(@"Avantgarde", @"Genres", @""),
			NSLocalizedStringFromTable(@"Gothic Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Progressive Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Psychedelic Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Symphonic Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Slow Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Big Band", @"Genres", @""),
			NSLocalizedStringFromTable(@"Chorus", @"Genres", @""),
			NSLocalizedStringFromTable(@"Easy Listening", @"Genres", @""),
			NSLocalizedStringFromTable(@"Acoustic", @"Genres", @""),
			NSLocalizedStringFromTable(@"Humour", @"Genres", @""),
			NSLocalizedStringFromTable(@"Speech", @"Genres", @""),
			NSLocalizedStringFromTable(@"Chanson", @"Genres", @""),
			NSLocalizedStringFromTable(@"Opera", @"Genres", @""),
			NSLocalizedStringFromTable(@"Chamber Music", @"Genres", @""),
			NSLocalizedStringFromTable(@"Sonata", @"Genres", @""),
			NSLocalizedStringFromTable(@"Symphony", @"Genres", @""),
			NSLocalizedStringFromTable(@"Booty Bass", @"Genres", @""),
			NSLocalizedStringFromTable(@"Primus", @"Genres", @""),
			NSLocalizedStringFromTable(@"Porn Groove", @"Genres", @""),
			NSLocalizedStringFromTable(@"Satire", @"Genres", @""),
			NSLocalizedStringFromTable(@"Slow Jam", @"Genres", @""),
			NSLocalizedStringFromTable(@"Club", @"Genres", @""),
			NSLocalizedStringFromTable(@"Tango", @"Genres", @""),
			NSLocalizedStringFromTable(@"Samba", @"Genres", @""),
			NSLocalizedStringFromTable(@"Folklore", @"Genres", @""),
			NSLocalizedStringFromTable(@"Ballad", @"Genres", @""),
			NSLocalizedStringFromTable(@"Power Ballad", @"Genres", @""),
			NSLocalizedStringFromTable(@"Rhythmic Soul", @"Genres", @""),
			NSLocalizedStringFromTable(@"Freestyle", @"Genres", @""),
			NSLocalizedStringFromTable(@"Duet", @"Genres", @""),
			NSLocalizedStringFromTable(@"Punk Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Drum Solo", @"Genres", @""),
			NSLocalizedStringFromTable(@"A cappella", @"Genres", @""),
			NSLocalizedStringFromTable(@"Euro-House", @"Genres", @""),
			NSLocalizedStringFromTable(@"Dance Hall", @"Genres", @""),
			NSLocalizedStringFromTable(@"Goa", @"Genres", @""),
			NSLocalizedStringFromTable(@"Drum & Bass", @"Genres", @""),
			NSLocalizedStringFromTable(@"Club-House", @"Genres", @""),
			NSLocalizedStringFromTable(@"Hardcore", @"Genres", @""),
			NSLocalizedStringFromTable(@"Terror", @"Genres", @""),
			NSLocalizedStringFromTable(@"Indie", @"Genres", @""),
			NSLocalizedStringFromTable(@"BritPop", @"Genres", @""),
			NSLocalizedStringFromTable(@"Negerpunk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Polsk Punk", @"Genres", @""),
			NSLocalizedStringFromTable(@"Beat", @"Genres", @""),
			NSLocalizedStringFromTable(@"Christian gangsta rap", @"Genres", @""),
			NSLocalizedStringFromTable(@"Heavy Metal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Black Metal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Crossover", @"Genres", @""),
			NSLocalizedStringFromTable(@"Contemporary Christian", @"Genres", @""),
			NSLocalizedStringFromTable(@"Christian Rock", @"Genres", @""),
			NSLocalizedStringFromTable(@"Merengue", @"Genres", @""),
			NSLocalizedStringFromTable(@"Salsa", @"Genres", @""),
			NSLocalizedStringFromTable(@"Thrash Metal", @"Genres", @""),
			NSLocalizedStringFromTable(@"Anime", @"Genres", @""),
			NSLocalizedStringFromTable(@"JPop", @"Genres", @""),
			NSLocalizedStringFromTable(@"Synthpop", @"Genres", @""),
			nil
			];
		[_unsortedGenres retain];
		_genres = [[_unsortedGenres sortedArrayUsingSelector:@selector(compare:)] retain];
	}
	return self;
}

+ (NSArray *) sharedGenres
{
	@synchronized(self) {
		if(nil == sharedGenres) {
			[[self alloc] init];
		}
	}
	return [sharedGenres valueForKey:@"genres"];
}

+ (NSArray *) unsortedGenres
{
	@synchronized(self) {
		if(nil == sharedGenres)
			[[self alloc] init];
	}
	return [sharedGenres valueForKey:@"unsortedGenres"];
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedGenres) {
            sharedGenres = [super allocWithZone:zone];
			return sharedGenres;
        }
    }
	return nil;
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (NSUInteger) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void) release											{ /* do nothing */ }
- (id) autorelease												{ return self; }

@end
