// Search for a track by title (and optionally by artist name). 
//
// Usage:
//	cdlookup_c [device] 
//
// $Id: cdlookup_c.c 8919 2007-03-19 20:27:18Z luks $

#include <stdio.h>
#include <musicbrainz3/mb_c.h>

int
main(int argc, char **argv)
{
    int i, size;
    char *device = NULL;
    char discid[100];
    MbDisc disc;
    MbQuery q;
    MbReleaseFilter f;
    MbResultList results;

    if (argc < 1) {
        printf("Usage: cdlookup [device]\n");
        return 1;
    }

    if (argc > 1)
        device = argv[1];

    disc = mb_read_disc(device);
    if (!disc) {
        printf("Error\n");
        return 1;
    }

    mb_disc_get_id(disc, discid, 100);
    printf("Disc Id: %s\n\n", discid);

    q = mb_query_new(NULL, NULL);
    f = mb_release_filter_new();
    mb_release_filter_disc_id(f, discid);
    results = mb_query_get_releases(q, f);
    mb_release_filter_free(f);
    mb_query_free(q);
    if (!results) {
        printf("Error\n");
        return 1;
    }

    size = mb_result_list_get_size(results);
    for (i = 0; i < size; i++) {
        char tmp[256];
        MbRelease release = mb_result_list_get_release(results, i);
        mb_release_get_id(release, tmp, 256);
        printf("Id    : %s\n", tmp);
        mb_release_get_title(release, tmp, 256);
        printf("Title : %s\n\n", tmp);
        mb_release_free(release);
    }
    mb_result_list_free(results);

    return 0;
}
