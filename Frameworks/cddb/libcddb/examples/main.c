/*
    $Id: main.c,v 1.27 2005/07/23 09:42:16 airborne Exp $

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

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "main.h"

/* command-line option string */

#ifdef HAVE_LIBCDIO
/* Allow -i <device> parameter */
#define OPT_STRING ":c:D:e:hi:l:p:P:qs:t"
#else
#define OPT_STRING ":c:D:e:hl:p:P:qs:t"
#endif

/* other stuff */
#define ENV_HTTP_PROXY "http_proxy"
#define HTTP_PREFIX "http://"
#define HTTP_PREFIX_LEN 7

/* parsed command-line parameters */
enum { CMD_NONE = 0, CMD_DISCID, CMD_QUERY, CMD_READ, CMD_SITES, CMD_SEARCH };
static int quiet = 0;           /* work silently, reports no errors */
static int command = 0;         /* request command */
static char *category = NULL;   /* category command-line argument */
static unsigned int discid = 0; /* disc ID command-line argument or calculated */
static int dlength = 0;         /* disc length command-line argument */
static int tcount = 0;          /* track count command-line parameter */
static int *foffset = NULL;     /* frame offset list command-line parameter */
static int use_cd = 0;          /* use CD-ROM to retrieve disc data */
static char *device = NULL;     /* device to use if use_cd == 1. NULL means 
                                   to find a suitable CD-ROM drive. */
static int use_time = 0;        /* use track times (in seconds) instead of frame offsets */
static char *charset = NULL;    /* requested character set encoding */
static char *searchstr = NULL;  /* text search string */

/* print usage message */
static void usage(void)
{
    fprintf(stderr, "Usage: cddb_query [OPTION] COMMAND [ARG]\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Available options:\n");
    fprintf(stderr, "  -c <mode>        local cache mode [on|off|only] (default = on)\n");
    fprintf(stderr, "  -D <cache dir>   directory for local cache (default = ~/.cddbslave)\n");
    fprintf(stderr, "  -e <charset>     character set encoding (default = UTF-8, see iconv -l)\n");
    fprintf(stderr, "  -h               display this help and exit\n");
#ifdef HAVE_LIBCDIO
    fprintf(stderr, "  -i <device>      use device to get disc data for commands\n");
#endif
    fprintf(stderr, "  -l <level>       log level, one of debug, info, warning, error or\n");
    fprintf(stderr, "                   critical (default = warning)\n");
    fprintf(stderr, "  -p <port>        port of CDDB server (default = 888)\n");
    fprintf(stderr, "  -P <protocol>    server protocol [cddbp|http|proxy] (default = cddbp)\n");
    fprintf(stderr, "  -q               quiet, do not print any error or log messages\n");
    fprintf(stderr, "  -s <server>      name of CDDB server (default = freedb.org)\n");
    fprintf(stderr, "  -t               use track times (in seconds) instead of frame offsets\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Available commands:\n");
    fprintf(stderr, "  calc <len> <n> <fo_1> ... <fo_n>\n");
    fprintf(stderr, "                   calculate disc ID\n");
    fprintf(stderr, "  query <len> <n> <fo_1> ... <fo_n>\n");
    fprintf(stderr, "                   query CDDB server and list all matching entries\n");
    fprintf(stderr, "  read <cat> <id>  retrieve disc details from CDDB server\n");
    fprintf(stderr, "  search <str>     perform a text search against the CDDB database\n");
    fprintf(stderr, "  sites            retrieve a list of mirror sites\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Command arguments\n");
    fprintf(stderr, "  <cat>            disc category (see below)\n");
    fprintf(stderr, "  <fo_i>           without -t: frame offset of track i\n");
    fprintf(stderr, "                   with -t:    length of track i in seconds\n");
    fprintf(stderr, "  <id>             disc ID in hexadecimal\n");
    fprintf(stderr, "  <len>            disc length in seconds\n");
    fprintf(stderr, "  <n>              track count\n");
    fprintf(stderr, "  <str>            search string\n");
    fprintf(stderr, "\n");
#ifdef HAVE_LIBCDIO
    fprintf(stderr, "If you do not specify any arguments for a command, the program\n");
    fprintf(stderr, "will try to retrieve the needed disc data from a CD in your CD-ROM\n");
    fprintf(stderr, "drive.\n");
#endif
    fprintf(stderr, "\n");
    fprintf(stderr, "Available CDDB categories are:\n");
    fprintf(stderr, "  data, folk, jazz, misc, rock, country, blues, newage, reggae,\n");
    fprintf(stderr, "  classical, and soundtrack\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Examples:\n");
    fprintf(stderr, "  To calculate the disc ID of the CD 'Mezzanine' from Massive Attack:\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "\tcddb_query calc 3822 11 150 28690 51102 75910 102682 \\\n");
    fprintf(stderr, "\t           121522 149040 175772 204387 231145 268065\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "  To query for matches of the CD 'Mezzanine' from Massive Attack:\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "\tcddb_query query 3822 11 150 28690 51102 75910 102682 \\\n");
    fprintf(stderr, "\t           121522 149040 175772 204387 231145 268065\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "  To read the details of the CD 'Mezzanine' from Massive Attack:\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "\tcddb_query read misc 0x920ef00b\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "  To search for all CDs with the string 'Mezzanine':\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "\tcddb_query search Mezzanine\n");
}

/* print error message */
static void prt_error(const char *fmt, va_list ap)
{
    if (!quiet) {
        fprintf(stderr, "\nerror: ");
        vfprintf(stderr, fmt, ap);
        fprintf(stderr, "\n\n");
    }
}

/* print error message and die */
void error_exit(int err, const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    prt_error(fmt, ap);
    va_end(ap);
    exit(err);
}

/* print error message, program usage and die */
static void error_usage(const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    prt_error(fmt, ap);
    va_end(ap);
    if (!quiet) {
        usage();
    }
    exit(GENERIC_ERROR);
}

#define CMD_STR(c) ((c) == CMD_DISCID ? "calc" : "query")
static void parse_disc_data(int cmd, int argc, char **argv, int idx)
{
    if (argc >= idx + 3) {
        /* at least two extra arguments are needed */
        sscanf(argv[idx+1], "%d", &dlength);
        sscanf(argv[idx+2], "%d", &tcount);
        if (argc == idx + tcount + 3) {
            /* parse frame offsets */
            if (tcount > 0) {
                int i;
                foffset = calloc(tcount, sizeof(int));
                for (i = 0; i < tcount; i++) {
                    sscanf(argv[idx+3+i], "%d", &foffset[i]);
                }
            }
        } else {
            error_usage("track count is %d, but %d frame offset(s) specified", tcount, (argc - idx - 3));
        }
    } else {
        error_usage("the %s command requires at least two arguments", CMD_STR(cmd));
    }
}

static void init_protocol(cddb_conn_t *conn, const char *proto)
{
    int len, port;
    char *aux, *host, *portstr, *password;

    if (!*optarg) {
        error_usage("-P, server protocol missing");
    }
    if (strcmp(optarg, "cddbp") == 0) {
        /* Enable the CDDBP protocol, i.e. disable the usage of HTTP.
           This is the default so actually this function call is not
           needed. */
        cddb_http_disable(conn);
    } else if (strcmp(optarg, "http") == 0) {
        /* Enable the HTTP protocol.  We will also set the server port
           to 80, i.e. the default HTTP port. */
        cddb_http_enable(conn);
        cddb_set_server_port(conn, 80);
    } else if (strcmp(optarg, "proxy") == 0) {
        /* Enable the HTTP protocol through a proxy server.  Enabling
           the proxy will automatically enable HTTP.  We will also set
           the server port to 80, i.e. the default HTTP port.  */
        cddb_http_proxy_enable(conn);
        cddb_set_server_port(conn, 80);
        /* We will retrieve the proxy settings from the environment
           variable 'http_proxy'.  If these do not exist, an error
           will be signaled. */
        aux = getenv(ENV_HTTP_PROXY);
        if (aux == NULL) {
            error_exit(GENERIC_ERROR, "environment variable 'http_proxy' not set");
        }
        /* Check the prefix.  It should be 'http://'. */
        if (strncmp(aux, HTTP_PREFIX, HTTP_PREFIX_LEN) != 0) {
            error_exit(GENERIC_ERROR, "environment variable 'http_proxy' invalid");
        }
        host = aux + HTTP_PREFIX_LEN;
        /* Check if a proxy username:password pair is provided */
        aux = strchr(host, '@');
        if (aux != NULL) {
            *aux = '\0';
            password = strchr(host, ':');
            if (password != NULL) {
                *password = '\0';
                password++;
            }
            cddb_set_http_proxy_credentials(conn, host, password);
            host = aux + 1;
        }
        /* Check if a proxy port is specified. */
        portstr = strchr(host, ':');
        if (portstr == NULL) {
            /* No port, set proxy server name and use default port 80. */
            cddb_set_http_proxy_server_name(conn, host);
            cddb_set_http_proxy_server_port(conn, 80);
        } else {
            /* A proxy port is present.  Parse it and initialize the
               connection structure with it. */
            portstr++;          /*  Skip colon. */
            port = strtol(portstr, &aux, 10);
            if (*aux != '\0' && *aux != '/') {
                error_exit(GENERIC_ERROR, "environment variable 'http_proxy' port invalid");
            }
            len = portstr - host - 1;
            aux = malloc(len + 1);
            strncpy(aux, host, len);
            aux[len] = '\0';
            cddb_set_http_proxy_server_name(conn, aux);
            cddb_set_http_proxy_server_port(conn, port);
        }
    } else {
        error_usage("-P, invalid server protocol '%s'", optarg);
    }
}

static void parse_cmdline(int argc, char **argv, cddb_conn_t *conn)
{
    int arg, port;
    char *aux;

    opterr = 0;
    while ((arg = getopt(argc, argv, OPT_STRING)) != -1) {
        switch ((char)arg) {
        case ':':               /* missing option argument */
            error_usage("-%c, option needs argument", optopt);
            break;
        case '?':               /* help */
        case 'h':               /* help */
            usage();
            exit(0);
            break;
        case 'c':               /* local cache settings */
            if (!*optarg) {
                error_usage("-c, cache mode missing");
            }
            if (strcmp(optarg, "on") == 0) {
                /* Enable the usage of the local CDDB cache (default).
                   This cache can be used to speed things up
                   drastically. */
                cddb_cache_enable(conn);
            } else if (strcmp(optarg, "off") == 0) {
                /* Disable the usage of the local CDDB cache. */
                cddb_cache_disable(conn);
            } else if (strcmp(optarg, "only") == 0) {
                /* Only use the local CDDB cache.  Never try reading
                   any data from the network. */
                cddb_cache_only(conn);
            } else {
                error_usage("-c, invalid cache mode '%s'", optarg);
            }
            break;
        case 'D':               /* local cache directory */
            if (!*optarg) {
                error_usage("-D, cache directory missing");
            }
            /* Set the location of the local CDDB cache directory.
               The default location of this directory is
               ~/.cddbslave. */
            cddb_cache_set_dir(conn, optarg);
            break;
        case 'e':
            if (!*optarg) {
                error_usage("-e, character set encoding missing");
            }
            charset = strdup(optarg);
            break;
        case 'i':               /* device for arguments */
            if (!*optarg) {
                error_usage("-i, device name missing");
            }
            use_cd = 1;
            device = strdup(optarg);
            break;
        case 'l':               /* log level */
            if (!*optarg) {
                error_usage("-l, log level missing");
            }
            if (strcmp(optarg, "debug") == 0) {
                cddb_log_set_level(CDDB_LOG_DEBUG);
            } else if (strcmp(optarg, "info") == 0) {
                cddb_log_set_level(CDDB_LOG_INFO);
            } else if (strcmp(optarg, "warning") == 0) {
                cddb_log_set_level(CDDB_LOG_WARN);
            } else if (strcmp(optarg, "error") == 0) {
                cddb_log_set_level(CDDB_LOG_ERROR);
            } else if (strcmp(optarg, "critical") == 0) {
                cddb_log_set_level(CDDB_LOG_CRITICAL);
            } else {
                error_usage("-l, invalid log level '%s'", optarg);
            }
            break;
        case 'p':               /* server port */
            if (!*optarg || *optarg == '\0') {
                error_usage("-p, server port missing");
            }
            port = strtol(optarg, &aux, 10);
            if (*aux != '\0') {
                error_usage("-p, invalid server port '%s'", optarg);
            }
            /* Initialize the CDDB server port.  This step can also be
               skipped if the default port (888) is good enough.  This
               default also matches the port of the FreeDB server. */
            cddb_set_server_port(conn, port);
            break;
        case 'P':               /* server protocol */
            init_protocol(conn, optarg);
            break;
        case 'q':               /* quiet */
            cddb_log_set_level(CDDB_LOG_NONE);
            quiet = 1;
            break;
        case 's':               /* server name */
            if (!*optarg) {
                /* server name missing */
                error_usage("-s, server name missing");
            }
            /* Initialize the CDDB server name.  Actually this call is
               optional because the default is 'freedb.org'.  So if
               the default is OK for you, then you can skip this
               step. */
            cddb_set_server_name(conn, optarg);
            break;
        case 't':               /* use track time */
            use_time = 1;
            break;
        }
    }

    if (argc <= optind) {
        /* no command given */
        error_usage("command missing");
    }

    /* use CD-ROM ? */
    if (argc == optind + 1) {
        use_cd = 1;
    }

    /* process command */
    if (strcmp(argv[optind], "calc") == 0) {
        /* calculate disc ID */
        command = CMD_DISCID;
        if (!use_cd) {
            /* check disc arguments */
            parse_disc_data(CMD_DISCID, argc, argv, optind);
        }
    } else if (strcmp(argv[optind], "query") == 0) {
        /* CDDB query */
        command = CMD_QUERY;
        if (!use_cd) {
            /* check disc arguments */
            parse_disc_data(CMD_QUERY, argc, argv, optind);
        }
    } else if (strcmp(argv[optind], "read") == 0) {
        /* CDDB read */
        command = CMD_READ;
        if (!use_cd) {
            if (argc == optind + 3) {
                /* two more arguments are needed */
                category = strdup(argv[optind+1]);
                sscanf(argv[optind+2], "%x", &discid);
            } else {
                error_usage("the read command requires two arguments");
            }
        }
    } else if (strcmp(argv[optind], "sites") == 0) {
        /* CDDB sites */
        command = CMD_SITES;
        if (argc != optind + 1) {
            error_usage("the sites command expects no arguments");
        }
        use_cd = 0;
    } else if (strcmp(argv[optind], "search") == 0) {
        /* CDDB search */
        command = CMD_SEARCH;
        if (argc == optind + 2) {
            /* one more argument is needed */
            searchstr = strdup(argv[optind+1]);
        } else {
            error_usage("the search command requires one argument");
        }
        use_cd = 0;
    } else {
        /* unknown command */
        error_usage("unknown command '%s'", argv[optind]);
    }
}

int main(int argc, char **argv)
{
    cddb_conn_t *conn = NULL;   /* libcddb connection structure */
    cddb_disc_t *disc = NULL;   /* libcddb disc structure */

    /* Create a new connection structure.  You will have to use this
       structure in most other calls to the libcddb library.  The
       connection settings will be updated while processing the
       command-line options. */
    conn = cddb_new();

    /* If the pointer is NULL then an error occured (out of memory). */
    if (!conn) {
        error_exit(GENERIC_ERROR, "unable to create connection structure");
    }

    /* Check command-line parameters. */
    parse_cmdline(argc, argv, conn);

    /* Initialize requested character set for output strings */
    if (charset) {
        if (!cddb_set_charset(conn, charset)) {
            error_exit(cddb_errno(conn), "could not set character encoding");
        }
    }

    /* Use CD-ROM to get some disc data? */
    if (use_cd) {
        /* Retrieve the disc length and track offsets from the CD in
           the CD-ROM drive. */
        disc = cd_read(device);
        if (!disc) {
            error_exit(GENERIC_ERROR, "could not read CD in CD-ROM drive");
        }
    } else if (command == CMD_DISCID || command == CMD_QUERY) {
        /* The disc ID calculation and query command both need a disc
           structure.  We will initialize a new disc with the data
           provided on the command-line. */
        disc = cd_create(dlength, tcount, foffset, use_time);
        if (!disc) {
            error_exit(GENERIC_ERROR, "could not create disc structure");
        }
        /* The frame offset data is no longer needed because it is now
           also present in the disc structure. */
        FREE_NOT_NULL(foffset);
    } else if (command == CMD_SEARCH) {
        /* Create an empty disc structure for the search command.  It
           will be used to store the search results. */
        disc = cddb_disc_new();
        if (!disc) {
            error_exit(GENERIC_ERROR, "could not create disc structure");
        }
    }

    /* Execute requested command. */
    switch (command) {
    case CMD_DISCID:
        /* Calculate the disc ID.  This function will initialize the
           disc ID field in the disc structure.  Afterwards you can
           retrieve the disc ID as shown below. */
        cddb_disc_calc_discid(disc);
        printf("CD disc ID is %08x\n", cddb_disc_get_discid(disc));
        break;
    case CMD_QUERY:
        /* Query the CDDB server for possibly matches. */
        do_query(conn, disc, quiet);
        break;
    case CMD_READ:
        /* If we read the disc data from a CD, then we first have to
           query the database for some extra information about the
           disc before we can read the details.  For a detailed
           description about querying see the do_query function.  Only
           the first match that is found will be used. */
        if (use_cd) {
            int matches;

            cddb_disc_calc_discid(disc);
            matches = cddb_query(conn, disc);
            if (matches == -1) {
                error_exit(cddb_errno(conn), "could not query");
            } else if (matches == 0) {
                error_exit(CDDB_ERR_DISC_NOT_FOUND, "no matching discs found");
            }
            /* Get the disc information needed for the read command.
               Afterwards we destroy the current disc because do_read
               will return a new disc. */
            category = strdup(cddb_disc_get_category_str(disc));
            discid = cddb_disc_get_discid(disc);
            cddb_disc_destroy(disc);
        }
        disc = do_read(conn, category, discid, quiet);
        if (!disc) {
            error_exit(cddb_errno(conn), "could not read disc data");
        }
        /* The category string is no longer needed because it is now
           also present in the disc structure. */
        FREE_NOT_NULL(category);
        /* Let's display the information that was read. */
        do_display(disc);
        break;
    case CMD_SITES:
        /* Display information about mirror sites. */
        do_sites(conn);
        break;
    case CMD_SEARCH:
        /* Search the CDDB database for possibly matches. */
        do_search(conn, disc, searchstr, quiet);
        break;
    }
    /* Finally, we have to clean up.  With the cddb_disc_destroy
       function we can easily free all memory used by a single disc.
       This function will free the memory used by the individual
       tracks of the disc and also free the memory of the disc
       structure itself.  Next we destroy the connection structrue in
       a similar way.  Both functions will first check whether the
       provided pointer is not NULL before freeing it. */
    cddb_disc_destroy(disc);
    cddb_destroy(conn);

    /* Also destroy any global resources reserved by the library. */
    libcddb_shutdown();

    FREE_NOT_NULL(charset);
    FREE_NOT_NULL(device);
    FREE_NOT_NULL(category);
    FREE_NOT_NULL(searchstr);

    return 0;
}
