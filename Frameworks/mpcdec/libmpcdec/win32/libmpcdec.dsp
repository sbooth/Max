# Microsoft Developer Studio Project File - Name="libmpcdec" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Static Library" 0x0104

CFG=libmpcdec - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "libmpcdec.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "libmpcdec.mak" CFG="libmpcdec - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "libmpcdec - Win32 Release" (based on "Win32 (x86) Static Library")
!MESSAGE "libmpcdec - Win32 Debug" (based on "Win32 (x86) Static Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=xicl6.exe
RSC=rc.exe

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "LibRelease"
# PROP Intermediate_Dir "LibRelease"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /YX /FD /c
# ADD CPP /nologo /W3 /O2 /I "..\include" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "MPC_LITTLE_ENDIAN" /FR /FD /c
# ADD BASE RSC /l 0x40c /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=xilink6.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "LibDebug"
# PROP Intermediate_Dir "LibDebug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /YX /FD /GZ /c
# ADD CPP /nologo /MTd /W3 /Gm /GX /ZI /Od /I "..\include" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "MPC_LITTLE_ENDIAN" /FD /GZ /c
# SUBTRACT CPP /YX
# ADD BASE RSC /l 0x40c /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=xilink6.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ENDIF 

# Begin Target

# Name "libmpcdec - Win32 Release"
# Name "libmpcdec - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=..\src\huffsv46.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\huffsv7.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\idtag.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\mpc_decoder.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\mpc_reader.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\requant.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\streaminfo.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\synth_filter.c

!IF  "$(CFG)" == "libmpcdec - Win32 Release"

# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "libmpcdec - Win32 Debug"

!ENDIF 

# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=..\include\mpcdec\config_win32.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\decoder.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\huffman.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\internal.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\math.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\mpcdec.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\reader.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\requant.h
# End Source File
# Begin Source File

SOURCE=..\include\mpcdec\streaminfo.h
# End Source File
# End Group
# End Target
# End Project
