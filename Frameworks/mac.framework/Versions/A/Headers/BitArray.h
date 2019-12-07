#pragma once

#include "IO.h"
#include "MD5.h"

namespace APE
{

//#define BUILD_RANGE_TABLE

struct RANGE_CODER_STRUCT_COMPRESS
{
    unsigned int low;        // low end of interval
    unsigned int range;        // length of interval
    unsigned int help;        // bytes_to_follow resp. intermediate value
    unsigned char buffer;    // buffer for input / output
};

struct BIT_ARRAY_STATE
{
    uint32 nKSum;
};

class CBitArray
{
public:    
    // construction / destruction
    CBitArray(APE::CIO *pIO);
    ~CBitArray();

    // encoding
    int EncodeUnsignedLong(unsigned int n);
    int EncodeValue(int nEncode, BIT_ARRAY_STATE & BitArrayState);
    int EncodeBits(unsigned int nValue, int nBits);

    // output (saving)
    int OutputBitArray(bool bFinalize = false);
    
    // other functions
    void Finalize();
    void AdvanceToByteBoundary();
    inline uint32 GetCurrentBitIndex() { return m_nCurrentBitIndex; }
    void FlushState(BIT_ARRAY_STATE & BitArrayState);
    void FlushBitArray();
    __forceinline CMD5Helper & GetMD5Helper() { return m_MD5; }
        
private:    
    // data members
    uint32 * m_pBitArray;
    CIO * m_pIO;
    uint32 m_nCurrentBitIndex;
    RANGE_CODER_STRUCT_COMPRESS m_RangeCoderInfo;
    CMD5Helper m_MD5;

#ifdef BUILD_RANGE_TABLE
    void OutputRangeTable();
#endif
};

}
