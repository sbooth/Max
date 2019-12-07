#pragma once

#include "APEDecompress.h"
#include "UnBitArrayBase.h"
#include "MACLib.h"
#include "Prepare.h"
#include "CircleBuffer.h"

namespace APE
{

class CUnBitArray;
class CPrepare;
class CAPEInfo;
class IPredictorDecompress;

class CAPEDecompress : public IAPEDecompress
{
public:
    CAPEDecompress(int * pErrorCode, CAPEInfo * pAPEInfo, int nStartBlock = -1, int nFinishBlock = -1);
    ~CAPEDecompress();

    int GetData(char * pBuffer, int nBlocks, int * pBlocksRetrieved);
    int Seek(int nBlockOffset);

    intn GetInfo(APE_DECOMPRESS_FIELDS Field, intn nParam1 = 0, intn nParam2 = 0);

protected:
    // file info
    int m_nBlockAlign;
    int m_nCurrentFrame;
    
    // start / finish information
    int m_nStartBlock;
    int m_nFinishBlock;
    int m_nCurrentBlock;
    bool m_bIsRanged;
    bool m_bDecompressorInitialized;

    // decoding tools    
    CPrepare m_Prepare;
    WAVEFORMATEX m_wfeInput;
    unsigned int m_nCRC;
    unsigned int m_nStoredCRC;
    int m_nSpecialCodes;
    
    int SeekToFrame(int nFrameIndex);
    void DecodeBlocksToFrameBuffer(int nBlocks);
    int FillFrameBuffer();
    void StartFrame();
    void EndFrame();
    int InitializeDecompressor();

    // more decoding components
    CSmartPtr<CAPEInfo> m_spAPEInfo;
    CSmartPtr<CUnBitArrayBase> m_spUnBitArray;
    UNBIT_ARRAY_STATE m_BitArrayStateX;
    UNBIT_ARRAY_STATE m_BitArrayStateY;

    CSmartPtr<IPredictorDecompress> m_spNewPredictorX;
    CSmartPtr<IPredictorDecompress> m_spNewPredictorY;

    int m_nLastX;
    
    // decoding buffer
    bool m_bErrorDecodingCurrentFrame;
    int m_nErrorDecodingCurrentFrameOutputSilenceBlocks;
    int m_nCurrentFrameBufferBlock;
    int m_nFrameBufferFinishedBlocks;
    CCircleBuffer m_cbFrameBuffer;
};

}
