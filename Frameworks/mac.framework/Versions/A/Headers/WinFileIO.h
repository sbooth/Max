#ifdef IO_USE_WIN_FILE_IO

#ifndef _winfileio_h_
#define _winfileio_h_

#include "IO.h"

namespace APE
{

class CWinFileIO : public CIO
{
public:
    // construction / destruction
    CWinFileIO();
    ~CWinFileIO();

    // open / close
    int Open(const wchar_t * pName, bool bOpenReadOnly = false);
    int Close();
    
    // read / write
    int Read(void * pBuffer, unsigned int nBytesToRead, unsigned int * pBytesRead);
    int Write(const void * pBuffer, unsigned int nBytesToWrite, unsigned int * pBytesWritten);
    
    // seek
    int Seek(int nDistance, unsigned int nMoveMode);
    
    // other functions
    int SetEOF();

    // creation / destruction
    int Create(const wchar_t * pName);
    int Delete();

    // attributes
    int GetPosition();
    unsigned int GetSize();
    int GetName(wchar_t * pBuffer);

private:
    
    HANDLE        m_hFile;
    wchar_t        m_cFileName[MAX_PATH];
    bool        m_bReadOnly;
};

}

#endif //_winfileio_h_

#endif //IO_USE_WIN_FILE_IO