/*
 * An implementation of the SHA-256 hash function, this is endian neutral
 * so should work just about anywhere.
 *
 * This code works much like the MD5 code provided by RSA.  You sha_init()
 * a "sha_state" then sha_process() the bytes you want and sha_done() to get
 * the output.
 *
 * Revised Code:  Complies to SHA-256 standard now.
 *
 * Tom St Denis -- http://tomstdenis.home.dhs.org
 * */
#include <stdio.h>

typedef struct {
    unsigned long state[8], length, curlen;
    unsigned char buf[64];
}
sha_state;

/* the K array */
static const unsigned long K[64] = {
    0x428a2f98UL, 0x71374491UL, 0xb5c0fbcfUL, 0xe9b5dba5UL, 0x3956c25bUL,
    0x59f111f1UL, 0x923f82a4UL, 0xab1c5ed5UL, 0xd807aa98UL, 0x12835b01UL,
    0x243185beUL, 0x550c7dc3UL, 0x72be5d74UL, 0x80deb1feUL, 0x9bdc06a7UL,
    0xc19bf174UL, 0xe49b69c1UL, 0xefbe4786UL, 0x0fc19dc6UL, 0x240ca1ccUL,
    0x2de92c6fUL, 0x4a7484aaUL, 0x5cb0a9dcUL, 0x76f988daUL, 0x983e5152UL,
    0xa831c66dUL, 0xb00327c8UL, 0xbf597fc7UL, 0xc6e00bf3UL, 0xd5a79147UL,
    0x06ca6351UL, 0x14292967UL, 0x27b70a85UL, 0x2e1b2138UL, 0x4d2c6dfcUL,
    0x53380d13UL, 0x650a7354UL, 0x766a0abbUL, 0x81c2c92eUL, 0x92722c85UL,
    0xa2bfe8a1UL, 0xa81a664bUL, 0xc24b8b70UL, 0xc76c51a3UL, 0xd192e819UL,
    0xd6990624UL, 0xf40e3585UL, 0x106aa070UL, 0x19a4c116UL, 0x1e376c08UL,
    0x2748774cUL, 0x34b0bcb5UL, 0x391c0cb3UL, 0x4ed8aa4aUL, 0x5b9cca4fUL,
    0x682e6ff3UL, 0x748f82eeUL, 0x78a5636fUL, 0x84c87814UL, 0x8cc70208UL,
    0x90befffaUL, 0xa4506cebUL, 0xbef9a3f7UL, 0xc67178f2UL
};

/* Various logical functions */
#define Ch(x,y,z)	((x & y) ^ (~x & z))
#define Maj(x,y,z)  ((x & y) ^ (x & z) ^ (y & z))
#define S(x, n)		(((x)>>((n)&31))|((x)<<(32-((n)&31))))
#define R(x, n)		((x)>>(n))
#define Sigma0(x)	(S(x, 2) ^ S(x, 13) ^ S(x, 22))
#define Sigma1(x)	(S(x, 6) ^ S(x, 11) ^ S(x, 25))
#define Gamma0(x)	(S(x, 7) ^ S(x, 18) ^ R(x, 3))
#define Gamma1(x)	(S(x, 17) ^ S(x, 19) ^ R(x, 10))

/* compress 512-bits */
static void sha_compress(sha_state * md)
{
    unsigned long S[8], W[64], t0, t1;
    int i;

    /* copy state into S */
    for (i = 0; i < 8; i++)
        S[i] = md->state[i];

    /* copy the state into 512-bits into W[0..15] */
    for (i = 0; i < 16; i++)
        W[i] = (((unsigned long) md->buf[(4 * i) + 0]) << 24) |
            (((unsigned long) md->buf[(4 * i) + 1]) << 16) |
            (((unsigned long) md->buf[(4 * i) + 2]) << 8) |
            (((unsigned long) md->buf[(4 * i) + 3]));

    /* fill W[16..63] */
    for (i = 16; i < 64; i++)
        W[i] = Gamma1(W[i - 2]) + W[i - 7] + Gamma0(W[i - 15]) + W[i - 16];

    /* Compress */
    for (i = 0; i < 64; i++) {
        t0 = S[7] + Sigma1(S[4]) + Ch(S[4], S[5], S[6]) + K[i] + W[i];
        t1 = Sigma0(S[0]) + Maj(S[0], S[1], S[2]);
        S[7] = S[6];
        S[6] = S[5];
        S[5] = S[4];
        S[4] = S[3] + t0;
        S[3] = S[2];
        S[2] = S[1];
        S[1] = S[0];
        S[0] = t0 + t1;
    }

    /* feedback */
    for (i = 0; i < 8; i++)
        md->state[i] += S[i];
}

/* init the SHA state */
void sha_init(sha_state * md)
{
    md->curlen = md->length = 0;
    md->state[0] = 0x6A09E667UL;
    md->state[1] = 0xBB67AE85UL;
    md->state[2] = 0x3C6EF372UL;
    md->state[3] = 0xA54FF53AUL;
    md->state[4] = 0x510E527FUL;
    md->state[5] = 0x9B05688CUL;
    md->state[6] = 0x1F83D9ABUL;
    md->state[7] = 0x5BE0CD19UL;
}

void sha_process(sha_state * md, unsigned char *buf, int len)
{
    while (len--) {
        /* copy byte */
        md->buf[md->curlen++] = *buf++;

        /* is 64 bytes full? */
        if (md->curlen == 64) {
            sha_compress(md);
            md->length += 512;
            md->curlen = 0;
        }
    }
}

void sha_done(sha_state * md, unsigned char *hash)
{
    int i;

    /* increase the length of the message */
    md->length += md->curlen * 8;

    /* append the '1' bit */
    md->buf[md->curlen++] = 0x80;

    /* if the length is currenlly above 56 bytes we append zeros
                               * then compress.  Then we can fall back to padding zeros and length
                               * encoding like normal.
                             */
    if (md->curlen >= 56) {
        for (; md->curlen < 64;)
            md->buf[md->curlen++] = 0;
        sha_compress(md);
        md->curlen = 0;
    }

    /* pad upto 56 bytes of zeroes */
    for (; md->curlen < 56;)
        md->buf[md->curlen++] = 0;

    /* since all messages are under 2^32 bits we mark the top bits zero */
    for (i = 56; i < 60; i++)
        md->buf[i] = 0;

    /* append length */
    for (i = 60; i < 64; i++)
        md->buf[i] = (md->length >> ((63 - i) * 8)) & 255;
    sha_compress(md);

    /* copy output */
    for (i = 0; i < 32; i++)
        hash[i] = (md->state[i >> 2] >> (((3 - i) & 3) << 3)) & 255;
}

/* sha-256 a block of memory */
void sha_memory(unsigned char *buf, int len, unsigned char *hash)
{
    sha_state md;

    sha_init(&md);
    sha_process(&md, buf, len);
    sha_done(&md, hash);
}

/* sha-256 a file, return 1 if ok */
int sha_file(const char *filename, unsigned char *hash)
{
    unsigned char buf[512];
    int i;
    FILE *in;
    sha_state md;

    sha_init(&md);
    in = fopen(filename, "rb");
    if (!in)
        return 0;
    do {
        i = (int)fread(buf, 1, 512, in);
        sha_process(&md, buf, i);
    }
    while (i == 512);
    sha_done(&md, hash);
    fclose(in);
    return 1;
}

/*int main(int argc, char **argv)
{
    int i, i2;
    unsigned char buf[32];

    if (argc == 1) {
        printf("Usage:\n%s: file1 [file2 file3 ...]\n", argv[0]);
        return 0;
    }

    for (i2 = 1; i2 < argc; i2++)
        if (sha_file(argv[i2], buf)) {
            printf("%24s: ", argv[i2]);
            for (i = 0; i < 32;) {
                printf("%02x", buf[i]);
                if (!(++i & 3))
                    printf(" ");
                if (i == 16)
                    printf("\n%26s", "");

            }
            printf("\n");
        }
    else
        printf("%20s: file not found.\n", argv[i2]);
    return 0;
}*/
/* crc==3210950260, version==3, Fri Mar 23 23:23:49 2001 */
