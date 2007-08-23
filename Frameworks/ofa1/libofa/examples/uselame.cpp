/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Public Domain (PD) 2006 MusicIP Corporation
   No rights reserved.

-------------------------------------------------------------------*/
#include "protocol.h"
#ifdef WIN32
#include "windows.h"
#else
#include <sys/wait.h>
#endif

AudioData *loadWaveFile(char *file);

//	loadDataUsingLAME
//
//	Opens an audio file and converts it to a temp .wav file
//	Calls loadWaveFile to load the data
//
AudioData* loadDataUsingLAME(char *file) {
    char *temp = "fpTemp.wav";
	
#ifdef WIN32
    STARTUPINFO si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    char * cmd = new char[1024];
    sprintf(cmd,"lame --decode \"%s\" fpTemp.wav", file);	
    if (!CreateProcess(NULL, // No module name (use command line).
		cmd,     // Command line.
		NULL,             // Process handle not inheritable.
		NULL,             // Thread handle not inheritable.
		FALSE,            // Set handle inheritance to FALSE.
		DETACHED_PROCESS, // Creation flags.
		NULL,             // Use parent's environment block.
		NULL,             // Use parent's starting directory.
		&si,              // Pointer to STARTUPINFO structure.
		&pi )             // Pointer to PROCESS_INFORMATION structure.
       )
    {
	return 0;
    }
    delete[] cmd;

    DWORD result = WaitForSingleObject(pi.hProcess, 1000000 /*INFINITE*/);
#else
    pid_t pid = fork();
    char * flag = "--decode";
    char * cmd = "lame"; // lame path
    char * argv[4] = {cmd, flag, file, temp};
    if (execv(cmd, (char **) argv) == -1) {
	return 0;
    }
    int exitCode = -1;
    pid = waitpid(pid, &exitCode, 0); // NYI: Implement timeout
    if (exitCode != 0) {
	return 0;
    }
#endif
    AudioData *data = loadWaveFile(temp);
    unlink(temp);
    return data;
}

