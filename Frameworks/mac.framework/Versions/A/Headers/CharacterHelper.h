#pragma once

namespace APE
{

/*******************************************************************************************
Character set conversion helpers
*******************************************************************************************/
class CAPECharacterHelper
{
public:
    static str_ansi * GetANSIFromUTF8(const str_utf8 * pUTF8);
    static str_ansi * GetANSIFromUTF16(const str_utfn * pUTF16);
    static str_utfn * GetUTF16FromANSI(const str_ansi * pANSI);
    static str_utfn * GetUTF16FromUTF8(const str_utf8 * pUTF8);
    static str_utf8 * GetUTF8FromANSI(const str_ansi * pANSI);
    static str_utf8 * GetUTF8FromUTF16(const str_utfn * pUTF16);
};

}
