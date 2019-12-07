#pragma once

#include "../APEDecompress.h"
#include "UnMAC.h"

namespace APE
{

class CAPEDecompressOld : public IAPEDecompress
{
public:
    CAPEDecompressOld(int * pErrorCode, CAPEInfo * pAPEInfo, int nStartBlock = -1, int nFinishBlock = -1);
    ~CAPEDecompressOld();

    int GetData(char * pBuffer, int nBlocks, int * pBlocksRetrieved);
    int Seek(int nBlockOffset);

    intn GetInfo(APE_DECOMPRESS_FIELDS Field, intn nParam1 = 0, intn nParam2 = 0);
    
protected:
    // buffer
    CSmartPtr<char> m_spBuffer;
    int m_nBufferTail;
    
    // file info
    int m_nBlockAlign;
    int m_nCurrentFrame;

    // start / finish information
    int m_nStartBlock;
    int m_nFinishBlock;
    int m_nCurrentBlock;
    bool m_bIsRanged;

    // decoding tools    
    CUnMAC m_UnMAC;
    CSmartPtr<CAPEInfo> m_spAPEInfo;
    
    bool m_bDecompressorInitialized;
    int InitializeDecompressor();
};

}

