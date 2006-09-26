/*
    $Id: cddb_net.c,v 1.18 2005/03/11 21:29:30 airborne Exp $

    Copyright (C) 2003, 2004, 2005 Kris Verbeeck <airborne@advalvas.be>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the
    Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.
*/

#include "cddb/cddb_ni.h"

#include <errno.h>

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#ifdef HAVE_NETDB_H
#include <netdb.h>
#endif

#include <setjmp.h>
#include <signal.h>

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_TIME_H
#include <time.h>
#endif
#if defined(HAVE_SYS_TIME_H) && defined(TIME_WITH_SYS_TIME)
#include <sys/time.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#ifdef HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif


/* Utility functions */


/**
 * Checks whether bytes can be read/written from/to the socket within
 * the specified time out period.
 *
 * @param sock     The socket to read from.
 * @param timeout  Number of seconds after which to time out.
 * @param to_write TRUE if we have to check for writing, FALSE for
 *                 reading.
 * @return TRUE if reading/writing is possible, FALSE otherwise.
 */
static int sock_ready(int sock, int timeout, int to_write)
{
    fd_set fds;
    struct timeval tv;
    int rv;

    //cddb_log_debug("sock_ready()");
    /* set up select time out */
    tv.tv_sec = timeout;
    tv.tv_usec = 0;
    /* set up file descriptor set */
    FD_ZERO(&fds);
    FD_SET(sock, &fds);
    /* wait for data to become available */
    if (to_write) {
        rv = select(sock + 1, NULL, &fds, NULL, &tv) ;
    } else {
        rv = select(sock + 1, &fds, NULL, NULL, &tv) ;
    }
    if (rv <= 0) {
        if (rv == 0) {
            errno = ETIMEDOUT;
        }
        return FALSE;
    }
    return TRUE;
}
#define sock_can_read(s,t) sock_ready(s, t, FALSE)
#define sock_can_write(s,t) sock_ready(s, t, TRUE)


/* Socket-based work-alikes */


char *sock_fgets(char *s, int size, cddb_conn_t *c)
{
    int rv;
    time_t now, end, timeout;
    char *p = s;

    cddb_log_debug("sock_fgets()");
    timeout = c->timeout;
    end = time(NULL) + timeout;
    size--;                      /* save one for terminating null */
    while (size) {
        now = time(NULL);
        timeout = end - now;
        if (timeout <= 0) {
            errno = ETIMEDOUT;
            return NULL;        /* time out */
        }
        /* can we read from the socket? */
        if (!sock_can_read(c->socket, timeout)) {
            /* error or time out */
            return NULL;
        }
        /* read one byte */
        rv = recv(c->socket, p, 1, 0);
        if (rv == -1) {
            /* recv() error */
            return NULL;
        } else if (rv == 0) {
            /* EOS reached */
            break;
        } else if (*p == CHR_LF) {
            /* EOL reached, stop reading */
            p++;
            break;
        }
        p++;
        size--;
    }
    if (p == s) {
        cddb_log_debug("...read = Empty");
        return NULL;
    }
    *p = CHR_EOS;
    cddb_log_debug("...read = '%s'", s);
    return s;
}

size_t sock_fwrite(const void *ptr, size_t size, size_t nmemb, cddb_conn_t *c)
{
    size_t total_size, to_send;
    time_t now, end, timeout;
    int rv;
    const char *p = (const char *)ptr;

    cddb_log_debug("sock_fwrite()");
    total_size = size * nmemb;
    to_send = total_size;
    timeout = c->timeout;
    end = time(NULL) + timeout;
    while (to_send) {
        now = time(NULL);
        timeout = end - now;
        if (timeout <= 0) {
            /* time out */
            errno = ETIMEDOUT;
            break;
        }
        /* can we write to the socket? */
        if (!sock_can_write(c->socket, timeout)) {
            /* error or time out */
            break;
        }
        /* try sending data */
        rv = send(c->socket, p, to_send, 0);
        if (rv == -1 && errno != EAGAIN && errno != EWOULDBLOCK) {
            /* error */
            break;
        } else {
            to_send -= rv;
            p += rv;
        }
    }
    return (total_size - to_send) / size;
}

int sock_fprintf(cddb_conn_t *c, const char *format, ...)
{
    int rv;
    va_list args;

    cddb_log_debug("sock_fprintf()");
    va_start(args, format);
    rv = sock_vfprintf(c, format, args);
    va_end(args);
    return rv;
}

int sock_vfprintf(cddb_conn_t *c, const char *format, va_list ap)
{
    char *buf;
    int rv;
   
    cddb_log_debug("sock_vfprintf()");
    buf = (char*)malloc(c->buf_size);
    rv = vsnprintf(buf, c->buf_size, format, ap);
    cddb_log_debug("...buf = '%s'", buf);
    if (rv < 0 || rv >= c->buf_size) {
        /* buffer too small */
        cddb_errno_log_crit(c, CDDB_ERR_LINE_SIZE);
        free(buf);
        return -1;
    }
    rv = sock_fwrite(buf, sizeof(char), rv, c);
    free(buf);
    return rv;
}

/* Time-out enabled work-alikes */

/* time-out jump buffer */
static jmp_buf timeout_expired;

/* time-out signal handler */
static void alarm_handler(int signum)
{
    longjmp(timeout_expired, 1);
}

struct hostent *timeout_gethostbyname(const char *hostname, int timeout)
{
    struct hostent *he = NULL;
    struct sigaction action;
    struct sigaction old;

    /* no signal before setjmp */
    alarm(0);

    /* register signal handler */
    memset(&action, 0, sizeof(action));
    action.sa_handler = alarm_handler;
    sigaction(SIGALRM, &action, &old);

    /* save stack state */
    if (!setjmp(timeout_expired)) {
        alarm(timeout);         /* set time-out alarm */
        he = gethostbyname(hostname); /* execute DNS query */
        alarm(0);               /* reset alarm timer */
    } else {
        errno = ETIMEDOUT;
    }
    sigaction(SIGALRM, &old, NULL); /* restore previous signal handler */

    return he;
}

int timeout_connect(int sockfd, const struct sockaddr *addr, 
                    size_t len, int timeout)
{
    int got_error = 0;

    /* set socket to non-blocking */
#ifdef BEOS
    int on = 1;

    if (setsockopt(sockfd, SOL_SOCKET, SO_NONBLOCK, &on, sizeof(on)) == -1) {
        /* error while trying to set socket to non-blocking */
        return -1;
    }
#else
    int flags;

    flags = fcntl(sockfd, F_GETFL, 0);
    flags |= O_NONBLOCK;        /* add non-blocking flag */
    if (fcntl(sockfd, F_SETFL, flags) == -1) {
        return -1;
    }
#endif /* BEOS */

    /* try connecting */
    if (connect(sockfd, addr, len) == -1) {
        /* check whether we can continue */
        if (errno == EINPROGRESS) {
            int rv;
            fd_set wfds;
            struct timeval tv;
            size_t l;

            /* set up select time out */
            tv.tv_sec = timeout;
            tv.tv_usec = 0;

            /* set up file descriptor set */
            FD_ZERO(&wfds);
            FD_SET(sockfd, &wfds);

            /* wait for connect to finish */
            rv = select(sockfd + 1, NULL, &wfds, NULL, &tv);
            switch (rv) {
            case 0:             /* time out */
                errno = ETIMEDOUT;
            case -1:            /* select error */
                got_error = -1;
            default:
                /* we got connected, check error condition */
                l = sizeof(rv);
                getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &rv, &l);
                if (rv) {
                    /* something went wrong, simulate normal connect behaviour */
                    errno = rv;
                    got_error = -1;
                }
            }
        }
    } else {
        /* connect failed */
        got_error = -1;
    }
    return got_error;
}
