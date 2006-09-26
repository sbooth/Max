#! /bin/sh

# cuetag.sh - tag files based on cue/toc file information
# uses cueprint output
# usage: cuetag.sh <cuefile|tocfile> [file]...

CUEPRINT=cueprint
cue_file=""

usage()
{
	echo "usage: cuetag.sh <cuefile|tocfile> [file]..."
}

# Vorbis Comments
# for FLAC and Ogg Vorbis files
vorbis()
{
	# FLAC tagging
	# --remove-vc-all overwrites existing comments
	METAFLAC="metaflac --remove-vc-all --import-vc-from=-"

	# Ogg Vorbis tagging
	# -w overwrites existing comments
	# -a appends to existing comments
	VORBISCOMMENT="vorbiscomment -w -c -"

	case "$2" in
	*.[Ff][Ll][Aa][Cc])
		VORBISTAG=$METAFLAC
		;;
	*.[Oo][Gg][Gg])
		VORBISTAG=$VORBISCOMMENT
		;;
	esac

	# space seperated list of recomended stardard field names
	# see http://www.xiph.org/ogg/vorbis/doc/v-comment.html
	# TRACKTOTAL is not in the Xiph recomendation, but is in common use
	
	fields='TITLE VERSION ALBUM TRACKNUMBER TRACKTOTAL ARTIST PERFORMER COPYRIGHT LICENSE ORGANIZATION DESCRIPTION GENRE DATE LOCATION CONTACT ISRC'

	# fields' corresponding cueprint conversion characters
	# seperate alternates with a space

	TITLE='%t'
	VERSION=''
	ALBUM='%T'
	TRACKNUMBER='%n'
	TRACKTOTAL='%N'
	ARTIST='%c %p'
	PERFORMER='%p'
	COPYRIGHT=''
	LICENSE=''
	ORGANIZATION=''
	DESCRIPTION='%m'
	GENRE='%g'
	DATE=''
	LOCATION=''
	CONTACT=''
	ISRC='%i %u'

	(for field in $fields; do
		value=""
		for conv in `eval echo \\$$field`; do
			value=`$CUEPRINT -n $1 -t "$conv\n" $cue_file`

			if [ -n "$value" ]; then
				echo "$field=$value"
				break
			fi
		done
	done) | $VORBISTAG "$2"
}

id3()
{
	MP3INFO=mp3info

	# space seperated list of ID3 v1.1 tags
	# see http://id3lib.sourceforge.net/id3/idev1.html

	fields="TITLE ALBUM ARTIST YEAR COMMENT GENRE TRACKNUMBER"

	# fields' corresponding cueprint conversion characters
	# seperate alternates with a space

	TITLE='%t'
	ALBUM='%T'
	ARTIST='%p'
	YEAR=''
	COMMENT='%c'
	GENRE='%g'
	TRACKNUMBER='%n'

	for field in $fields; do
		value=""
		for conv in `eval echo \\$$field`; do
			value=`$CUEPRINT -n $1 -t "$conv\n" $cue_file`

			if [ -n "$value" ]; then
				break
			fi
		done

		if [ -n "$value" ]; then
			case $field in
			TITLE)
				$MP3INFO -t "$value" "$2"
				;;
			ALBUM)
				$MP3INFO -l "$value" "$2"
				;;
			ARTIST)
				$MP3INFO -a "$value" "$2"
				;;
			YEAR)
				$MP3INFO -y "$value" "$2"
				;;
			COMMENT)
				$MP3INFO -c "$value" "$2"
				;;
			GENRE)
				$MP3INFO -g "$value" "$2"
				;;
			TRACKNUMBER)
				$MP3INFO -n "$value" "$2"
				;;
			esac
		fi
	done
}

main()
{
	if [ $# -lt 1 ]; then
		usage
		exit
	fi

	cue_file=$1
	shift

	ntrack=`cueprint -d '%N' $cue_file`
	trackno=1

	if [ $# -ne $ntrack ]; then
		echo "warning: number of files does not match number of tracks"
	fi

	for file in $@; do
		case $file in
		*.[Ff][Ll][Aa][Cc])
			vorbis $trackno "$file"
			;;
		*.[Oo][Gg][Gg])
			vorbis $trackno "$file"
			;;
		*.[Mm][Pp]3)
			id3 $trackno "$file"
			;;
		*)
			echo "$file: uknown file type"
			;;
		esac
		trackno=$(($trackno + 1))
	done
}

main "$@"
