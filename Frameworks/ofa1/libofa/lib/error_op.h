/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "error_op.h"
// MODULE: Header for error object OnePrintError. Client can catch or ignore.
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#ifndef ERR_H_OP
#define ERR_H_OP 1

#include <string> 
using namespace std;

const int  NOFLCODE = -1;
const int  SILENCEONLY = 1;
const int  GENERALFAILURE = 2;
const int FILETOOSHORT = 10;


class OnePrintError {
public:
	OnePrintError(string s) { Mes = s; ErrorCode = NOFLCODE; }
	OnePrintError(string s, int code) { Mes = s; ErrorCode = code; }
	OnePrintError(const int code) { ErrorCode = code; }
	string GetMessage() { return Mes; }
	long GetErrorCode() { return ErrorCode; }
	void SetErrorCode(const int code) { ErrorCode = code; }
private:
	string Mes;
	int ErrorCode;
};



#endif

