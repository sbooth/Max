/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Public Domain (PD) 2006 MusicIP Corporation
   No rights reserved.

-------------------------------------------------------------------*/
#include "protocol.h"
#ifdef WIN32
#include "io.h"
#endif
#include <fcntl.h>

static bool readBytes(int fd, unsigned char *buf, int size) {
    int ct = 0;
    while (ct < size) {
	unsigned char tmp[4096];

	int x = size - ct;
	if (x > 4096)
	    x = 4096;

	int n = read(fd, tmp, x);

	if (n <= 0) {
	    return false;
	}

	for (int i = 0; i < n; ++i) {
	    buf[ct + i] = tmp[i];
	}
	ct += n;
    }
    return true;
}

// This method only supports PCM/uncompressed format, with a single fmt
// chunk followed by a single data chunk
AudioData* loadWaveFile(char *file) {

    int srate = 0;
    int channels = 0;

    int fd = open(file, O_RDONLY | 0x8000);
    if (fd == -1)
	return 0;

    if (lseek(fd, 0L, SEEK_SET) == -1L) {
	close(fd);
	return 0;
    }

    unsigned char hdr[36];
    if (!readBytes(fd, hdr, 36)) {
	close(fd);
	return 0;
    }
    if (hdr[0] != 'R' || hdr[1] != 'I' || hdr[2] != 'F' || hdr[3] != 'F') {
	close(fd);
	return 0;
    }
    // Note: bytes 4 thru 7 contain the file size - 8 bytes
    if (hdr[8] != 'W' || hdr[9] != 'A' || hdr[10] != 'V' || hdr[11] != 'E') {
	close(fd);
	return 0;
    }
    if (hdr[12] != 'f' || hdr[13] != 'm' || hdr[14] != 't' || hdr[15] != ' ') {
	close(fd);
	return 0;
    }

    long extraBytes = hdr[16] + (hdr[17] << 8) + (hdr[18] << 16) + (hdr[19] << 24) - 16;
    int compression = hdr[20] + (hdr[21] << 8);
    // Type 1 is PCM/Uncompressed
    if (compression != 1) {
	close(fd);
	return 0;
    }
    channels = hdr[22] + (hdr[23] << 8);
    // Only mono or stereo PCM is supported in this example
    if (channels < 1 || channels > 2) {
	close(fd);
	return 0;
    }
    // Samples per second, independent of number of channels
    srate = hdr[24] + (hdr[25] << 8) + (hdr[26] << 16) + (hdr[27] << 24);
    // Bytes 28-31 contain the "average bytes per second", unneeded here
    // Bytes 32-33 contain the number of bytes per sample (includes channels)
    // Bytes 34-35 contain the number of bits per single sample
    int bits = hdr[34] + (hdr[35] << 8);
    // Supporting othe sample depths will require conversion
    if (bits != 16) {
	close(fd);
	return 0;
    }

    // Skip past extra bytes, if any
    if (lseek(fd, 36L + extraBytes, SEEK_SET) == -1L) {
	close(fd);
	return 0;
    }

    // Start reading the next frame.  Only supported frame is the data block
    unsigned char b[8];
    if (!readBytes(fd, b, 8)) {
	close(fd);
	return 0;
    }
    // Do we have a fact block?
    if (b[0] == 'f' && b[1] == 'a' && b[2] == 'c' && b[3] == 't') {
	// Skip the fact block
	if (lseek(fd, 36L + extraBytes + 12L, SEEK_SET) == -1L) {
	    close(fd);
	    return 0;
	}
	// Read the next frame
	if (!readBytes(fd, b, 8)) {
	    close(fd);
	    return 0;
	}
    }

    // Now look for the data block
    if (b[0] != 'd' || b[1] != 'a' || b[2] != 't' || b[3] != 'a') {
	close(fd);
	return 0;
    }
    long bytes = b[4] + (b[5] << 8) + (b[6] << 16) + (b[7] << 24);

    long ms = (bytes/2)/(srate/1000);
    if ( channels == 2 ) ms /= 2;

    // No need to read the whole file, just the first 135 seconds
    int sampleSize = 135;
    long bytesInNSecs = sampleSize * srate * 2 * channels;
    bytes = bytes > bytesInNSecs ? bytesInNSecs : bytes;

    unsigned char *samples = new unsigned char[bytes];
    if (!readBytes(fd, samples, bytes)) {
	delete[] samples;
	close(fd);
	return 0;
    }
    close(fd);

    AudioData *data = new AudioData();
    data->setData(samples, OFA_LITTLE_ENDIAN, bytes/2, srate,
	    channels == 2 ? 1 : 0, ms, "wav");
    return data;
}
