/* Get artist by id. 
 * 
 * Usage:
 *  getartist 'artist id'
 *
 * $Id: getartist_c.c 8247 2006-07-22 19:29:52Z luks $
 */

#include <stdio.h>
#include <musicbrainz3/mb_c.h>

int
main(int argc, char **argv)
{
	MbQuery query;
	MbArtist artist;
	char data[256];
	
	if (argc < 2) {
		printf("Usage: getartist 'artist id'\n");
		return 1;
	}
	
	query = mb_query_new(NULL, NULL);
	
	artist = mb_query_get_artist_by_id(query, argv[1], NULL);
	if (!artist) {
		printf("No artist returned.\n");
		mb_query_free(query);
		return 1;
	}
	
	mb_artist_get_id(artist, data, 256);
	printf("Id      : %s\n", data);
	
	mb_artist_get_type(artist, data, 256);
	printf("Type	: %s\n", data);
	
	mb_artist_get_name(artist, data, 256);
	printf("Name	: %s\n", data);
	
	mb_artist_get_sortname(artist, data, 256);
	printf("SortName: %s\n", data);

	mb_artist_free(artist);
	
	mb_query_free(query);
	
	return 0;
}

