#include "All.h"
#include "GlobalFunctions.h"
#include "IO.h"
#include "CharacterHelper.h"

/*
#ifndef __GNUC_IA32__

extern "C" bool GetMMXAvailable(void)
{
#ifdef ENABLE_ASSEMBLY

    unsigned long nRegisterEDX;

    try
    {
        __asm mov eax, 1
        __asm CPUID
        __asm mov nRegisterEDX, edx
       }
    catch(...)
    {
        return false;
    }

    if (nRegisterEDX & 0x800000) 
        RETURN_ON_EXCEPTION(__asm emms, false)
    else
        return false;

    return true;

#else
    return false;
#endif
}

#endif // #ifndef __GNUC_IA32__
*/

int ReadSafe(CIO * pIO, void * pBuffer, int nBytes)
{
    unsigned int nBytesRead = 0;
    int nRetVal = pIO->Read(pBuffer, nBytes, &nBytesRead);
    if (nRetVal == ERROR_SUCCESS)
    {
        if (nBytes != int(nBytesRead))
            nRetVal = ERROR_IO_READ;
    }

    return nRetVal;
}

int WriteSafe(CIO * pIO, void * pBuffer, int nBytes)
{
    unsigned int nBytesWritten = 0;
    int nRetVal = pIO->Write(pBuffer, nBytes, &nBytesWritten);
    if (nRetVal == ERROR_SUCCESS)
    {
        if (nBytes != int(nBytesWritten))
            nRetVal = ERROR_IO_WRITE;
    }

    return nRetVal;
}

bool FileExists(wchar_t * pFilename)
{    
    if (0 == wcscmp(pFilename, L"-")  ||  0 == wcscmp(pFilename, L"/dev/stdin"))
        return true;

#ifdef _WIN32

    bool bFound = false;

    WIN32_FIND_DATA WFD;
    HANDLE hFind = FindFirstFile(pFilename, &WFD);
    if (hFind != INVALID_HANDLE_VALUE)
    {
        bFound = true;
        CloseHandle(hFind);
    }

    return bFound;

#else

    CSmartPtr<char> spANSI(GetANSIFromUTF16(pFilename), true);

    struct stat b;

    if (stat(spANSI, &b) != 0)
        return false;

    if (!S_ISREG(b.st_mode))
        return false;

    return true;

#endif
}
