/*
 *  Beep-Carbon-Debugging.h
 *  Beep-Carbon
 *
 *  Created by Mac-arena the Bored Zo on Wed Jun 16 2004.
 *  Public domain.
 *
 */

#ifdef DEBUG
#	define DEBUG_print(s) fputs(s, stdout)
#	define DEBUG_printf1(fmt, arg0) printf(fmt, arg0)
#	define DEBUG_printf2(fmt, arg0, arg1) printf(fmt, arg0, arg1)
#	define DEBUG_printf5(fmt, arg0, arg1, arg2, arg3, arg4) printf(fmt, arg0, arg1, arg2, arg3, arg4)
#	define DEBUG_printf6(fmt, arg0, arg1, arg2, arg3, arg4, arg5) printf(fmt, arg0, arg1, arg2, arg3, arg4, arg5)
#else
#	define DEBUG_print(s) /*debug print here*/
#	define DEBUG_printf1(fmt, arg0) /*debug print with one arg here*/
#	define DEBUG_printf2(fmt, arg0, arg1) /*debug print with two args here*/
#	define DEBUG_printf5(fmt, arg0, arg1, arg2, arg3, arg4) /*debug print with five args here*/
#	define DEBUG_printf6(fmt, arg0, arg1, arg2, arg3, arg4, arg5) /*debug print with six args here*/
#endif
