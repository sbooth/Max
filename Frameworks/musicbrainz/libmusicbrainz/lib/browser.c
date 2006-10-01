/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: browser.c 784 2006-03-04 15:46:34Z luks $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/stat.h>
#endif
#include <string.h>

/* The following functions are for launching the browser */
#ifdef WIN32

int LaunchBrowser(const char* url, const char *browser)
{
    int foo = (int)ShellExecute(NULL, "open", url, NULL, NULL, SW_SHOWNORMAL);
    return 1;
}

#else

#ifdef __APPLE__

int LaunchBrowser(const char* url, const char *browser)
{
    char *cmd = malloc(strlen(url) + 32);
    sprintf(cmd, "open '%s'", url);
    system(cmd);
    free(cmd);
}

#else

int Launch(const char *url, const char *command);
int LaunchUsingEnvvar(const char *url);
int IsNetscapeRunning(void);

int LaunchBrowser(const char* url, const char *browser)
{
    char         command[1024];
    char        *browser_env;

    browser_env = getenv("BROWSER");
    if (browser_env && strlen(browser_env) > 0)
        return LaunchUsingEnvvar(url);

    if (browser == NULL)
       return 0;

    if (strcmp(browser, "netscape") == 0)
    {
        if (IsNetscapeRunning())
             strcpy(command, "netscape -raise -remote "
                             "\"openURL(file://%s,new-window)\""); 
        else
             strcpy(command, "netscape \"file://%s\" &");
    }
    else
        sprintf(command, "%s '%%s' &", browser);

    return Launch(url, command);
}

int LaunchUsingEnvvar(const char *url)
{
    char *browser, *token;
    int   ret = 0;

    browser = strdup(getenv("BROWSER"));
    token = strtok(browser, ":");
    while(token && *token)
    {
        ret = Launch(url, token);
        if (ret)
           break;

        token = strtok(NULL, ":");
    }
    free(browser);

    return ret;
}

int Launch(const char *url, const char *browser)
{
    char *command, *ptr, newBrowser[1024];
    int   ret;

    ptr = strchr(browser, '%');
    if (ptr && ptr > browser && *(ptr-1) != '"' && *(ptr-1) != '\'')
    {
        *ptr = 0;
        sprintf(newBrowser, "%s\"%%s\"", browser);  
        browser = newBrowser;
    }

    command = malloc(strlen(browser) + strlen(url) + 10);
    sprintf(command, browser, url);

    ret = system(command) >> 8;
    if (ret == 127)
       ret = 0;
    else
       ret = 1;

    free(command);
    return ret;
}

int IsNetscapeRunning(void)
{
    struct stat  sb;
    char        *home, lockfile[1024];

    home = getenv("HOME");
    if (!home) 
        return 0;

    sprintf(lockfile,"%.200s/.netscape/lock",home);
    return (lstat(lockfile, &sb) != -1);
}

#endif

#endif
