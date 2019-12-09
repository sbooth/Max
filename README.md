# Max

**Main website:** [https://sbooth.org/Max/](https://sbooth.org/Max/)


Max is an application for creating high-quality audio files in various formats, on macOS (32-bit), from compact discs
or files.

When extracting audio from compact discs, Max offers the maximum in flexibility to ensure the true sound of your CD is faithfully extracted. For pristine discs, Max offers a high-speed ripper with no error correction. For damaged discs, Max can either use its built-in comparison ripper (for drives that cache audio) or the error-correcting power of cdparanoia.

Once the audio is extracted, Max can generate audio in over 20 compressed and uncompressed formats including MP3, Ogg Vorbis, FLAC, AAC, Apple Lossless, Monkey's Audio, WavPack, Speex, AIFF, and WAVE.

If you would like to convert your audio from one format to another, Max can read and write audio files in over 20 compressed and uncompressed formats at almost all sample rates and and in most sample sizes. For many popular formats the artist and album metadata is transferred seamlessly between the old and new files. Max can even split a single audio file into multiple tracks using a cue sheet.

Max leverages open source components and the resources of Mac OS X to provide extremely high-quality output. For example, MP3 encoding is accomplished with LAME, Ogg Vorbis encoding with aoTuV, FLAC encoding with libFLAC, and AAC and Apple Lossless encoding with Core Audio. Many PCM conversions are also possible using Core Audio and libsndfile.

Max is integrated with MusicBrainz to permit automatic retrieval of compact disc information. For MP3, FLAC, Ogg FLAC, Ogg Vorbis, Monkey's Audio, WavPack, AAC and Apple Lossless files Max will write this metadata to the output.

Max allows full control over where output files are placed and what they are named. If desired, Max will even add the encoded files to your iTunes library in a playlist of your choice.

For advanced users, Max allows control over how many threads are used for encoding, what type of error correction is used for audio extraction, and what parameters are used for each of the various encoders.

Max is free software released under the GNU General Public License (GPL).

# Requirements

Max is designed for macOS and is currently limited to
32-bit capable environments, which means up to and 
including macOS 10.14.

# Binaries

If you would rather download a binary version for
general consumption, rather than download from source,
please visit the [Max website](https://sbooth.org/Max/).

# Support

Need help with Max? The [forums] (https://forums.sbooth.org/) are a good place to look for answers to common questions.

Bugs can be reported via the [GitHub issue tracker](https://github.com/sbooth/Max/issues) or via [launchad](https://bugs.launchpad.net/maxosx).

# Building

Max is built use XCode, with the main project file being
[Max.xcodeproj](./Max.xcodeproj)


