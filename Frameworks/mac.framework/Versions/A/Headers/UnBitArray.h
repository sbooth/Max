#pragma once

#include "UnBitArrayBase.h"

namespace APE
{

class IAPEDecompress;

struct RANGE_CODER_STRUCT_DECOMPRESS
{
    unsigned int low;       // low end of interval
    unsigned int range;     // length of interval
    unsigned int buffer;    // buffer for input/output
};

class CUnBitArray : public CUnBitArrayBase
{
public:
    // construction/destruction
    CUnBitArray(APE::CIO * pIO, int nVersion, int nFurthestReadByte);
    ~CUnBitArray();

    unsigned int DecodeValue(DECODE_VALUE_METHOD DecodeMethod, int nParam1 = 0, int nParam2 = 0);
    
    void GenerateArray(int * pOutputArray, int nElements, int nBytesRequired = -1);
    
    int DecodeValueRange(UNBIT_ARRAY_STATE & BitArrayState);

    void FlushState(UNBIT_ARRAY_STATE & BitArrayState);
    void FlushBitArray();
    void Finalize();
    
private:
    void GenerateArrayRange(int * pOutputArray, int nElements);
    
    // data 
    int m_nFlushCounter;
    int m_nFinalizeCounter;
    RANGE_CODER_STRUCT_DECOMPRESS m_RangeCoderInfo;
    
    // functions
    inline uint32 DecodeByte();
    inline int RangeDecodeFast(int nShift);
    inline int RangeDecodeFastWithUpdate(int nShift);
};

}
