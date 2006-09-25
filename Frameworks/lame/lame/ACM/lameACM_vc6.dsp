# Microsoft Developer Studio Project File - Name="lameACM" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Dynamic-Link Library" 0x0102

CFG=lameACM - Win32 Debug NASM
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "lameACM_vc6.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "lameACM_vc6.mak" CFG="lameACM - Win32 Debug NASM"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "lameACM - Win32 Release" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "lameACM - Win32 Debug" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "lameACM - Win32 Debug NASM" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "lameACM - Win32 Release NASM" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "lameACM - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MT /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /YX /FD /c
# ADD CPP /nologo /Zp2 /MT /W3 /GX /Ox /Ot /Og /Ob2 /I "../libmp3lame" /I "../include" /I ".." /I "../.." /I "../mpglib" /I "./" /D "NDEBUG" /D "_BLADEDLL" /D "TAKEHIRO_IEEE754_HACK" /D "HAVE_CONFIG_H" /D "HAVE_MPGLIB" /D "_WINDOWS" /D "WIN32" /D "NOANALYSIS" /D "LAME_ACM" /YX /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /o /win32 "NUL"
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /o /win32 "NUL"
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /dll /machine:I386
# ADD LINK32 shell32.lib url.lib gdi32.lib winmm.lib advapi32.lib user32.lib kernel32.lib libc.lib libcp.lib /nologo /subsystem:windows /dll /map /machine:I386 /nodefaultlib /out:"..\output\lameACM.acm"
# Begin Special Build Tool
SOURCE="$(InputPath)"
PostBuild_Cmds=copy lameacm.inf ..\output\*.*	copy lame_acm.xml ..\output\*.*
# End Special Build Tool

!ELSEIF  "$(CFG)" == "lameACM - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MTd /W3 /Gm /GX /Zi /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /YX /FD /c
# ADD CPP /nologo /Zp2 /MTd /W3 /GX /ZI /Od /I "../libmp3lame" /I "../include" /I ".." /I "../.." /I "../mpglib" /I "./" /D "_DEBUG" /D "_BLADEDLL" /D "TAKEHIRO_IEEE754_HACK" /D "HAVE_CONFIG_H" /D "HAVE_MPGLIB" /D "_WINDOWS" /D "WIN32" /D "NOANALYSIS" /D "LAME_ACM" /YX /FD /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /o /win32 "NUL"
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /o /win32 "NUL"
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /dll /debug /machine:I386 /pdbtype:sept
# ADD LINK32 shell32.lib url.lib gdi32.lib winmm.lib advapi32.lib user32.lib kernel32.lib libcd.lib libcpd.lib /nologo /subsystem:windows /dll /debug /machine:I386 /nodefaultlib /out:"..\output\lameACM.acm" /pdbtype:sept
# SUBTRACT LINK32 /map
# Begin Special Build Tool
SOURCE="$(InputPath)"
PostBuild_Cmds=copy lameacm.inf ..\output\*.*	copy lame_acm.xml ..\output\*.*
# End Special Build Tool

!ELSEIF  "$(CFG)" == "lameACM - Win32 Debug NASM"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug_NASM"
# PROP BASE Intermediate_Dir "Debug_NASM"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug_NASM"
# PROP Intermediate_Dir "Debug_NASM"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /Zp2 /MTd /W3 /Gm /GX /Zi /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /YX /FD /c
# ADD CPP /nologo /Zp2 /MTd /W3 /GX /ZI /Od /I "../libmp3lame" /I "../include" /I ".." /I "../.." /I "../mpglib" /I "./" /D "_DEBUG" /D "HAVE_NASM" /D "MMX_choose_table" /D "_BLADEDLL" /D "TAKEHIRO_IEEE754_HACK" /D "HAVE_CONFIG_H" /D "HAVE_MPGLIB" /D "_WINDOWS" /D "WIN32" /D "NOANALYSIS" /D "LAME_ACM" /YX /FD /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /o /win32 "NUL"
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /o /win32 "NUL"
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /dll /debug /machine:I386 /pdbtype:sept
# SUBTRACT BASE LINK32 /map
# ADD LINK32 shell32.lib url.lib gdi32.lib winmm.lib advapi32.lib user32.lib kernel32.lib libcd.lib libcpd.lib ADbg/Debug/adbg.lib tinyxml/Debug/tinyxml.lib /nologo /subsystem:windows /dll /debug /machine:I386 /nodefaultlib /out:"..\output\lameACM.acm" /pdbtype:sept
# SUBTRACT LINK32 /map
# Begin Special Build Tool
SOURCE="$(InputPath)"
PostBuild_Cmds=copy lameacm.inf ..\output\*.*	copy lame_acm.xml ..\output\*.*
# End Special Build Tool

!ELSEIF  "$(CFG)" == "lameACM - Win32 Release NASM"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release_NASM"
# PROP BASE Intermediate_Dir "Release_NASM"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release_NASM"
# PROP Intermediate_Dir "Release_NASM"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /Zp2 /MT /W3 /GX /Ox /Ot /Og /Ob2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /YX /FD /c
# ADD CPP /nologo /Zp2 /MT /W3 /GX /Ox /Ot /Og /Ob2 /I "../libmp3lame" /I "../include" /I ".." /I "../.." /I "../mpglib" /I "./" /D "NDEBUG" /D "HAVE_NASM" /D "MMX_choose_table" /D "_BLADEDLL" /D "TAKEHIRO_IEEE754_HACK" /D "HAVE_CONFIG_H" /D "HAVE_MPGLIB" /D "_WINDOWS" /D "WIN32" /D "NOANALYSIS" /D "LAME_ACM" /YX /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /o /win32 "NUL"
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /o /win32 "NUL"
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /dll /map /machine:I386
# ADD LINK32 shell32.lib url.lib gdi32.lib winmm.lib advapi32.lib user32.lib kernel32.lib libc.lib libcp.lib ADbg\Release\adbg.lib tinyxml/Release/tinyxml.lib /nologo /subsystem:windows /dll /map /machine:I386 /nodefaultlib /out:"..\output\lameACM.acm"
# Begin Special Build Tool
SOURCE="$(InputPath)"
PostBuild_Cmds=copy lameacm.inf ..\output\*.*	copy lame_acm.xml ..\output\*.*
# End Special Build Tool

!ENDIF 

# Begin Target

# Name "lameACM - Win32 Release"
# Name "lameACM - Win32 Debug"
# Name "lameACM - Win32 Debug NASM"
# Name "lameACM - Win32 Release NASM"
# Begin Group "Source"

# PROP Default_Filter "c;cpp"
# Begin Source File

SOURCE=.\ACM.cpp
# End Source File
# Begin Source File

SOURCE=.\ACMStream.cpp
# End Source File
# Begin Source File

SOURCE=.\AEncodeProperties.cpp
# End Source File
# Begin Source File

SOURCE=.\DecodeStream.cpp
# End Source File
# Begin Source File

SOURCE=.\lameACM.def
# End Source File
# Begin Source File

SOURCE=.\main.cpp
# End Source File
# End Group
# Begin Group "Include"

# PROP Default_Filter "h"
# Begin Source File

SOURCE=.\ACM.h
# End Source File
# Begin Source File

SOURCE=.\ACMStream.h
# End Source File
# Begin Source File

SOURCE=.\adebug.h
# End Source File
# Begin Source File

SOURCE=.\AEncodeProperties.h
# End Source File
# Begin Source File

SOURCE=.\DecodeStream.h
# End Source File
# End Group
# Begin Group "Resource"

# PROP Default_Filter "rc"
# Begin Source File

SOURCE=.\acm.rc
# End Source File
# Begin Source File

SOURCE=.\lame.ico
# End Source File
# End Group
# Begin Group "Install"

# PROP Default_Filter "inf;acm"
# Begin Source File

SOURCE=.\LameACM.inf
# End Source File
# End Group
# Begin Source File

SOURCE=.\readme.txt
# End Source File
# Begin Source File

SOURCE=.\TODO
# End Source File
# End Target
# End Project
