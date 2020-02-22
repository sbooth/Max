# Max

**Main website:** [https://sbooth.org/Max/](https://sbooth.org/Max/)

Max is an application for creating high-quality audio files in various formats, from compact discs or files.

When extracting audio from compact discs, Max offers the maximum in flexibility to ensure the true sound of your CD is faithfully extracted.  For pristine discs, Max offers a high-speed ripper with no error correction.  For damaged discs, Max can either use its built-in comparison ripper (for drives that cache audio) or the error-correcting power of [cdparanoia](https://www.xiph.org/paranoia/).

Once the audio is extracted, Max can generate audio in over 20 compressed and uncompressed formats including MP3, Ogg Vorbis, FLAC, AAC, Apple Lossless, Monkey's Audio, WavPack, Speex, AIFF, and WAVE.

If you would like to convert your audio from one format to another, Max can read and write audio files in over 20 compressed and uncompressed formats at almost all sample rates and and in most sample sizes.  For many popular formats the artist and album metadata is transferred seamlessly between the old and new files.  Max can even split a single audio file into multiple tracks using a cue sheet.

Max leverages open source components and the resources of macOS to provide extremely high-quality output.  For example, MP3 encoding is accomplished with [LAME](https://lame.sourceforge.io), Ogg Vorbis encoding with [libVorbis](https://xiph.org/vorbis/), FLAC encoding with [libFLAC](https://xiph.org/flac/), and AAC and Apple Lossless encoding with [Core Audio](http://www.apple.com/macosx/features/coreaudio/).  Many PCM conversions are also possible using Core Audio and [libsndfile](http://www.mega-nerd.com/libsndfile/).

Max is integrated with [MusicBrainz](https://musicbrainz.org) to permit automatic retrieval of compact disc information.  For MP3, FLAC, Ogg FLAC, Ogg Vorbis, Monkey's Audio, WavPack, AAC and Apple Lossless files Max will write this metadata to the output.

Max allows full control over where output files are placed and what they are named.  If desired, Max will even add the encoded files to your iTunes library in a playlist of your choice.

For advanced users, Max allows control over how many threads are used for encoding, what type of error correction is used for audio extraction, and what parameters are used for each of the various encoders.

Max is free software released under the [GNU General Public License](http://www.gnu.org/licenses/licenses.html#GPL) (GPL).

# Requirements

macOS 10.7 or greater.

# Binaries

If you would prefer to download a binary version rather than build from source, please visit the [Max website](https://sbooth.org/Max/).

# Support

Need help with Max? The [forums](https://forums.sbooth.org/) are a good place to look for answers to common questions.

Bugs can be reported via the [GitHub issue tracker](https://github.com/sbooth/Max/issues).

# Building

Max is built use Xcode 11.
