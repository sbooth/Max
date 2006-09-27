/*
 * The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 * 
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 * 
 * The Original Code is MPEG4IP.
 * 
 * The Initial Developer of the Original Code is Cisco Systems Inc.
 * Portions created by Cisco Systems Inc. are
 * Copyright (C) Cisco Systems Inc. 2001.  All Rights Reserved.
 * 
 * Contributor(s): 
 *		Bill May wmay@cisco.com
 */

// N.B. mp4extract just extracts tracks/samples from an mp4 file
// For many track types this is insufficient to reconsruct a valid
// elementary stream (ES). Use "mp4creator -extract=<trackId>" if
// you need the ES reconstructed. 

#include "mp4.h"
#include "mpeg4ip_getopt.h"

static bool compare_duration(char *toname, MP4FileHandle to, 
			     char *fromname, MP4FileHandle from)
{
  MP4Duration todur, fromdur;

  todur = MP4GetTrackDuration(to, 1);
  fromdur = MP4GetTrackDuration(from, 1);
  if (todur == fromdur) return true;
  printf("%s durations do not match "U64" "U64"\n", fromname,
	 fromdur, todur);
  return false;
}

static void sync_duration (char *toFileName, 
			   MP4FileHandle durfile)
{
  MP4Duration todur;
  MP4FileHandle tofile;
  char newname[PATH_MAX];
  todur = MP4GetTrackDuration(durfile, 1) + 1024;
  tmpnam(newname);
  MP4FileHandle fromfile;
  uint32_t numTracks;

  fromfile = MP4Modify(toFileName);
  
  tofile = MP4Create(newname);
  numTracks = MP4GetNumberOfTracks(fromfile);
  for (uint32_t ix = 0; ix < numTracks; ix++) {
    MP4TrackId trackId = MP4FindTrackId(fromfile, ix);
    MP4EditId eid = MP4AddTrackEdit(fromfile, trackId, 1, 0, todur);
    if (eid == MP4_INVALID_EDIT_ID) {
      printf("invalid edit\n");
    } else {
      MP4CopyTrack(fromfile, trackId, tofile, true);
      MP4DeleteTrackEdit(fromfile, trackId, eid);
    }
  }

  MP4Close(tofile);
  MP4Close(fromfile);
  unlink(toFileName);
  rename(newname, toFileName);
}


static bool compare_meta(char *toname, MP4FileHandle to, 
			 char *fromname, MP4FileHandle from)
{
  char *tovalue, *fromvalue;
  uint16_t tonum, tonum2, fromnum, fromnum2;
  uint32_t toverb, fromverb;

  toverb = MP4GetVerbosity(to);
  MP4SetVerbosity(to, 0);
  fromverb = MP4GetVerbosity(from);
  MP4SetVerbosity(from, 0);

  tovalue = fromvalue = NULL;
  MP4GetMetadataName(to, &tovalue);
  MP4GetMetadataName(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    printf("%s name \"%s\" \"%s\"\n", 
	   fromname, fromvalue, tovalue);
    CHECK_AND_FREE(tovalue);
    CHECK_AND_FREE(fromvalue);
    return false;
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataArtist(to, &tovalue);
  MP4GetMetadataArtist(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    printf("%s artist \"%s\" \"%s\"\n", 
	   fromname, fromvalue, tovalue);
    CHECK_AND_FREE(tovalue);
    CHECK_AND_FREE(fromvalue);
    return false;
  }

  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataWriter(to, &tovalue);
  MP4GetMetadataWriter(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL || fromvalue != NULL) {
      printf("%s writer \"%s\" \"%s\"\n", 
	     fromname, fromvalue, tovalue);
      CHECK_AND_FREE(tovalue);
      CHECK_AND_FREE(fromvalue);
      return false;
    }
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataYear(to, &tovalue);
  MP4GetMetadataYear(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    printf("%s year \"%s\" \"%s\"\n", 
	   fromname, fromvalue, tovalue);
    CHECK_AND_FREE(tovalue);
    CHECK_AND_FREE(fromvalue);
    return false;
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataAlbum(to, &tovalue);
  MP4GetMetadataAlbum(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    printf("%s album \"%s\" \"%s\"\n", 
	   fromname, fromvalue, tovalue);
    CHECK_AND_FREE(tovalue);
    CHECK_AND_FREE(fromvalue);
    return false;
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataGenre(to, &tovalue);
  MP4GetMetadataGenre(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    printf("%s genre \"%s\" \"%s\"\n", 
	   fromname, fromvalue, tovalue);
    CHECK_AND_FREE(tovalue);
    CHECK_AND_FREE(fromvalue);
    return false;
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataGrouping(to, &tovalue);
  MP4GetMetadataGrouping(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL || fromvalue != NULL) {
      printf("%s grouping \"%s\" \"%s\"\n", 
	     fromname, fromvalue, tovalue);
      CHECK_AND_FREE(tovalue);
      CHECK_AND_FREE(fromvalue);
      return false;
    }
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataComment(to, &tovalue);
  MP4GetMetadataComment(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL || fromvalue != NULL) {
      printf("%s comment \"%s\" \"%s\"\n", 
	     fromname, fromvalue, tovalue);
      CHECK_AND_FREE(tovalue);
      CHECK_AND_FREE(fromvalue);
      return false;
    }
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataTempo(to, &tonum);
  MP4GetMetadataTempo(from, &fromnum);
  if (tonum != fromnum) {
    printf("%s tempo %u %u \n", 
	   fromname, fromnum, tonum);
    return false;
  }

  MP4GetMetadataTrack(to, &tonum, &tonum2);
  MP4GetMetadataTrack(from, &fromnum, &fromnum2);
  if (tonum != fromnum || tonum2 != fromnum2) {
    printf("%s track %u %u from %u %u\n", 
	   fromname, tonum, tonum2, fromnum, fromnum2);
    return false;
  }

  MP4GetMetadataDisk(to, &tonum, &tonum2);
  MP4GetMetadataDisk(from, &fromnum, &fromnum2);
  if (tonum != fromnum || tonum2 != fromnum2) {
    printf("%s disk %u %u from %u %u\n", 
	   fromname, tonum, tonum2, fromnum, fromnum2);
    return false;
  }

  uint32_t toart, fromart;
  toart = MP4GetMetadataCoverArtCount(to);
  fromart = MP4GetMetadataCoverArtCount(from);
  if (toart != fromart) {
    printf("%s art count %u %u\n", fromname, toart, fromart);
    return false;
  }
  MP4SetVerbosity(to, toverb);
  MP4SetVerbosity(from, fromverb);
  return true;
}


static void copy_meta(char *toname, MP4FileHandle to, 
		      char *fromname, MP4FileHandle from)
{
  char *tovalue, *fromvalue;
  uint16_t tonum, tonum2, fromnum, fromnum2;
  uint32_t toverb, fromverb;

  toverb = MP4GetVerbosity(to);
  MP4SetVerbosity(to, 0);
  fromverb = MP4GetVerbosity(from);
  MP4SetVerbosity(from, 0);

  tovalue = fromvalue = NULL;
  MP4GetMetadataName(to, &tovalue);
  MP4GetMetadataName(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataName(to);
    if (fromvalue != NULL)
      MP4SetMetadataName(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataArtist(to, &tovalue);
  MP4GetMetadataArtist(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataArtist(to);
    if (fromvalue != NULL)
      MP4SetMetadataArtist(to, fromvalue);
  }

  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataWriter(to, &tovalue);
  MP4GetMetadataWriter(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataWriter(to);
    if (fromvalue != NULL)
      MP4SetMetadataWriter(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataYear(to, &tovalue);
  MP4GetMetadataYear(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataYear(to);
    if (fromvalue != NULL)
      MP4SetMetadataYear(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);
  MP4GetMetadataAlbum(to, &tovalue);
  MP4GetMetadataAlbum(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataAlbum(to);
    if (fromvalue != NULL)
      MP4SetMetadataAlbum(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataGenre(to, &tovalue);
  MP4GetMetadataGenre(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataGenre(to);
    if (fromvalue != NULL)
      MP4SetMetadataGenre(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataGrouping(to, &tovalue);
  MP4GetMetadataGrouping(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataGrouping(to);
    if (fromvalue != NULL)
      MP4SetMetadataGrouping(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataComment(to, &tovalue);
  MP4GetMetadataComment(from, &fromvalue);
  if (tovalue == NULL || fromvalue == NULL || strcmp(tovalue, fromvalue) != 0) {
    if (tovalue != NULL) 
      MP4DeleteMetadataComment(to);
    if (fromvalue != NULL)
      MP4SetMetadataComment(to, fromvalue);
  }
  CHECK_AND_FREE(tovalue);
  CHECK_AND_FREE(fromvalue);

  MP4GetMetadataTempo(to, &tonum);
  MP4GetMetadataTempo(from, &fromnum);
  if (tonum != fromnum) {
    MP4DeleteMetadataTempo(to);
    MP4SetMetadataTempo(to, fromnum);
  }

  MP4GetMetadataTrack(to, &tonum, &tonum2);
  MP4GetMetadataTrack(from, &fromnum, &fromnum2);
  if (tonum != fromnum || tonum2 != fromnum2) {
    MP4DeleteMetadataTrack(to);
    MP4SetMetadataTrack(to, fromnum, fromnum2);
  }

  MP4GetMetadataDisk(to, &tonum, &tonum2);
  MP4GetMetadataDisk(from, &fromnum, &fromnum2);
  if (tonum != fromnum || tonum2 != fromnum2) {
    MP4DeleteMetadataDisk(to);
    MP4SetMetadataDisk(to, fromnum, fromnum2);
  }

  uint32_t toart, fromart;
  toart = MP4GetMetadataCoverArtCount(to);
  fromart = MP4GetMetadataCoverArtCount(from);
  if (toart != fromart) {
    uint8_t *art;
    uint32_t artsize;
    MP4GetMetadataCoverArt(from, &art, &artsize);
    if (toart != 0) MP4DeleteMetadataCoverArt(to);
    if (fromart != 0) 
      MP4SetMetadataCoverArt(to, art, artsize);
  }

  MP4SetVerbosity(to, toverb);
  MP4SetVerbosity(from, fromverb);
}
#if 0
void transit (char *to, char *from)
{
  do {
    if (*from == ' ') {
      *to++ = '\\';
    }
    *to++ = *from;
  } while (*from++ != '\0');
}
#endif
char* ProgName;

int main(int argc, char** argv)
{
  const char* usageString = 
    "[-l] [-t <track-id>] [-s <sample-id>] [-v [<level>]] <file-name>\n";
  char* difflist;
  char Mp4FileName[PATH_MAX], toFileName[PATH_MAX];
#if 0
  MP4TrackId trackId = MP4_INVALID_TRACK_ID;
  MP4SampleId sampleId = MP4_INVALID_SAMPLE_ID;
#endif
  u_int32_t verbosity = MP4_DETAILS_ERROR;

  /* begin processing command line */
  ProgName = argv[0];
  while (true) {
    int c = -1;
    int option_index = 0;
    static struct option long_options[] = {
      { "verbose", 2, 0, 'v' },
      { "version", 0, 0, 'V' },
      { NULL, 0, 0, 0 }
    };

    c = getopt_long_only(argc, argv, "v::V",
			 long_options, &option_index);

    if (c == -1)
      break;

    switch (c) {
    case 'v':
      verbosity |= MP4_DETAILS_READ;
      if (optarg) {
	u_int32_t level;
	if (sscanf(optarg, "%u", &level) == 1) {
	  if (level >= 2) {
	    verbosity |= MP4_DETAILS_TABLE;
	  } 
	  if (level >= 3) {
	    verbosity |= MP4_DETAILS_SAMPLE;
	  } 
	  if (level >= 4) {
	    verbosity = MP4_DETAILS_ALL;
	  }
	}
      }
      break;
    case '?':
      fprintf(stderr, "usage: %s %s", ProgName, usageString);
      exit(0);
    case 'V':
      fprintf(stderr, "%s - %s version %s\n", 
	      ProgName, MPEG4IP_PACKAGE, MPEG4IP_VERSION);
      exit(0);
    default:
      fprintf(stderr, "%s: unknown option specified, ignoring: %c\n", 
	      ProgName, c);
    }
  }

  /* check that we have at least one non-option argument */
  if ((argc - optind) < 1) {
    fprintf(stderr, "usage: %s %s", ProgName, usageString);
    exit(1);
  }
	
  if (verbosity) {
    fprintf(stderr, "%s version %s\n", ProgName, MPEG4IP_VERSION);
  }

  /* warn about extraneous non-option arguments */
  /* end processing of command line */

  while (optind < argc) {
    difflist = argv[optind++];
    FILE *lfile = fopen(difflist, "r");
    while (fgets(Mp4FileName, PATH_MAX, lfile) != NULL) {
      //transit(Mp4FileName, trans);
      uint len = strlen(Mp4FileName);
      len--;
      while (isspace(Mp4FileName[len])) {
	Mp4FileName[len] = '\0';
	len--;
      }
      MP4FileHandle mp4File = MP4Read(Mp4FileName, verbosity);
	
      if (!mp4File) {
	printf("Cannot open %s\n", Mp4FileName);
      } else {
	//printf("trying %s\n", Mp4FileName);
	bool found = false;
	struct stat statbuf;
	strcpy(toFileName, Mp4FileName);
	toFileName[strlen(toFileName) - 1] = 'a';
	if (stat(toFileName, &statbuf) == 0 &&
	    S_ISREG(statbuf.st_mode)) {
	  found = true;
	} else {
	  char *lastslash = strrchr(toFileName, '/');
	  lastslash++;
	  if (lastslash[2] != ' ') {
	    char *nextspace = lastslash;
	    while (!isspace(*nextspace)) nextspace++;
	    char *to = lastslash + 2;
	    do {
	      *to++ = *nextspace++;
	    } while (*nextspace != '\0');
	    *to = '\0';
	  }
	  for (uint ix = 1; ix < 36 && found == false; ix++) {
	    lastslash[0] = (ix / 10) + '0';
	    lastslash[1] = (ix % 10) + '0';
	    if (stat(toFileName, &statbuf) == 0 &&
		S_ISREG(statbuf.st_mode)) {
	      found = true;
	    }
	  }
	}
	if (found == false) {
	  printf("Couldn't find %s\n", Mp4FileName);
	} else {
	  MP4FileHandle toFile = MP4Read(toFileName, verbosity);
	  if (!toFile) {
	    printf("Cannot open %s\n", toFileName);
	  } else {
	    if (compare_duration(toFileName, toFile, Mp4FileName, mp4File) == false) {
	      MP4Close(toFile);
	      sync_duration(toFileName, mp4File);
	      toFile = MP4Read(toFileName, verbosity);
	    }
	    if (compare_meta(toFileName, toFile, Mp4FileName, mp4File) == false) {
	      printf("need meta fixup %s\n", Mp4FileName);
	      MP4Close(toFile);
	      toFile = MP4Modify(toFileName, verbosity);
	      copy_meta(toFileName, toFile, Mp4FileName, mp4File);
	    }
	    MP4Close(toFile);
	  }
	}
	MP4Close(mp4File);
      }
    }
    fclose(lfile);
  }

  return(0);
}

