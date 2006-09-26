/* Eliminate teeny little writes.  patch submitted by 
   Rob Ross <rbross@parl.ces.clemson.edu> --Monty 19991008 */

#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

#define OUTBUFSZ 32*1024

#include "utils.h"
extern long blocking_write(int outf, char *buffer, long num);


/* GLOBALS FOR BUFFERING CALLS */
static int  bw_fd  = -1;
static long bw_pos = 0;
static char bw_outbuf[OUTBUFSZ];


/* buffering_write() - buffers data to a specified size before writing.
 *
 * Restrictions:
 * - MUST CALL BUFFERING_CLOSE() WHEN FINISHED!!!
 *
 */
long buffering_write(int fd, char *buffer, long num)
{
	if (fd != bw_fd) {
		/* clean up after buffering for some other file */
		if (bw_fd >= 0 && bw_pos > 0) {
			if (blocking_write(bw_fd, bw_outbuf, bw_pos)) {
				perror("write (in buffering_write, flushing)");
			}
		}
		bw_fd  = fd;
		bw_pos = 0;
	}

	if (bw_pos + num > OUTBUFSZ) {
		/* fill our buffer first, then write, then modify buffer and num */
		memcpy(&bw_outbuf[bw_pos], buffer, OUTBUFSZ - bw_pos);
		if (blocking_write(fd, bw_outbuf, OUTBUFSZ)) {
			perror("write (in buffering_write, full buffer)");
			return(-1);
		}
		num -= (OUTBUFSZ - bw_pos);
		buffer += (OUTBUFSZ - bw_pos);
		bw_pos = 0;
	}
	/* save data */
	memcpy(&bw_outbuf[bw_pos], buffer, num);
	bw_pos += num;

	return(0);
}

/* buffering_close() - writes out remaining buffered data before closing
 * file.
 *
 */
int buffering_close(int fd)
{
	if (fd == bw_fd && bw_pos > 0) {
		/* write out remaining data and clean up */
		if (blocking_write(fd, bw_outbuf, bw_pos)) {
			perror("write (in buffering_close)");
		}
		bw_fd  = -1;
		bw_pos = 0;
	}
	return(close(fd));
}
