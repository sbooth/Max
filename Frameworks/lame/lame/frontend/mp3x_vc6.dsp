# Microsoft Developer Studio Project File - Name="MP3x" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Console Application" 0x0103

CFG=MP3x - Win32 Debug GTK
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "mp3x_vc6.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "mp3x_vc6.mak" CFG="MP3x - Win32 Debug GTK"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "MP3x - Win32 Debug GTK" (based on "Win32 (x86) Console Application")
!MESSAGE "MP3x - Win32 Release GTK" (based on "Win32 (x86) Console Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "MP3x - Win32 Debug GTK"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "MP3x___Win32_Debug_GTK"
# PROP BASE Intermediate_Dir "MP3x___Win32_Debug_GTK"
# PROP BASE Ignore_Export_Lib 0
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "MP3x___Win32_Debug_GTK"
# PROP Intermediate_Dir "MP3x___Win32_Debug_GTK"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /ZI /Od /I "./WinGtk/src/gtk+" /I "./WinGtk/src/glib" /I "./WinGtk/src/gtk+/gdk" /I "../include" /I "../libmp3lame" /I "../mp3x" /I "../frontend" /I ".." /D "_DEBUG" /D "WIN32" /D "_CONSOLE" /D "_MBCS" /D "HAVE_GTK" /D "HAVE_MPGLIB" /D "LAMESNDFILE" /D "BRHIST" /D "HAVE_CONFIG_H" /FD /c
# SUBTRACT BASE CPP /YX
# ADD CPP /nologo /W3 /Gm /ZI /Od /I "./WinGtk/src/gtk+" /I "./WinGtk/src/glib" /I "./WinGtk/src/gtk+/gdk" /I "../include" /I "../libmp3lame" /I "../mp3x" /I "../frontend" /I ".." /D "_MBCS" /D "HAVE_GTK" /D "LAMESNDFILE" /D "BRHIST" /D "_DEBUG" /D "WIN32" /D "_CONSOLE" /D "HAVE_MPGLIB" /D "HAVE_CONFIG_H" /FD /c
# SUBTRACT CPP /YX
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 glib-2.0.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib gdk.lib gtk.lib /nologo /subsystem:console /debug /machine:I386 /out:"../output/mp3x.exe" /pdbtype:sept /libpath:"./WinGtk/src/gtk+/gtk" /libpath:"./WinGtk/src/gtk+/gdk" /libpath:"./WinGtk/src/glib"
# ADD LINK32 glib-2.0.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib gdk.lib gtk.lib /nologo /subsystem:console /debug /machine:I386 /out:"../output/mp3x.exe" /pdbtype:sept /libpath:"./WinGtk/src/gtk+/gtk" /libpath:"./WinGtk/src/gtk+/gdk" /libpath:"./WinGtk/src/glib"

!ELSEIF  "$(CFG)" == "MP3x - Win32 Release GTK"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "MP3x___Win32_Release_GTK"
# PROP BASE Intermediate_Dir "MP3x___Win32_Release_GTK"
# PROP BASE Ignore_Export_Lib 0
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "MP3x___Win32_Release_GTK"
# PROP Intermediate_Dir "MP3x___Win32_Release_GTK"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /O2 /I "./WinGTK/gtk-plus" /I "./WinGTK/glib-1.2" /I "./WinGtk/src/gtk+" /I "./WinGtk/src/glib" /I "./WinGtk/src/gtk+/gdk" /I "../include" /I "../libmp3lame" /I "../mp3x" /I "../frontend" /I ".." /D "NDEBUG" /D "LAMEPARSE" /D "WIN32" /D "_CONSOLE" /D "_MBCS" /D "HAVE_GTK" /D "HAVE_MPGLIB" /D "LAMESNDFILE" /D "BRHIST" /D "HAVE_CONFIG_H" /FD /c
# SUBTRACT BASE CPP /YX
# ADD CPP /nologo /W3 /O2 /I "./WinGTK/gtk-plus" /I "./WinGTK/glib-1.2" /I "./WinGtk/src/gtk+" /I "./WinGtk/src/glib" /I "./WinGtk/src/gtk+/gdk" /I "../include" /I "../libmp3lame" /I "../mp3x" /I "../frontend" /I ".." /D "NDEBUG" /D "LAMEPARSE" /D "WIN32" /D "_CONSOLE" /D "_MBCS" /D "HAVE_GTK" /D "HAVE_MPGLIB" /D "LAMESNDFILE" /D "BRHIST" /D "HAVE_CONFIG_H" /FD /c
# SUBTRACT CPP /YX
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 glib-1.3.lib glib-2.0.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib gdk.lib gtk.lib /nologo /subsystem:console /profile /map /machine:I386 /out:"../output/mp3x.exe" /libpath:"./WinGtk/src/gtk+/gtk" /libpath:"./WinGtk/src/gtk+/gdk" /libpath:"./WinGtk/src/glib"
# ADD LINK32 glib-2.0.lib glib-2.0.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib gdk.lib gtk.lib /nologo /subsystem:console /profile /map /machine:I386 /out:"../output/mp3x.exe" /libpath:"./WinGtk/src/gtk+/gtk" /libpath:"./WinGtk/src/gtk+/gdk" /libpath:"./WinGtk/src/glib"

!ENDIF 

# Begin Target

# Name "MP3x - Win32 Debug GTK"
# Name "MP3x - Win32 Release GTK"
# Begin Group "Source"

# PROP Default_Filter "c"
# Begin Source File

SOURCE=..\frontend\brhist.c
# End Source File
# Begin Source File

SOURCE=..\frontend\get_audio.c
# End Source File
# Begin Source File

SOURCE=.\gpkplotting.c
# End Source File
# Begin Source File

SOURCE=.\gtkanal.c
# End Source File
# Begin Source File

SOURCE=..\frontend\lametime.c
# End Source File
# Begin Source File

SOURCE=.\mp3x.c
# End Source File
# Begin Source File

SOURCE=..\frontend\parse.c
# End Source File
# Begin Source File

SOURCE=..\frontend\portableio.c
# End Source File
# Begin Source File

SOURCE=..\frontend\timestatus.c
# End Source File
# End Group
# Begin Group "Include"

# PROP Default_Filter "h"
# Begin Source File

SOURCE=..\frontend\brhist.h
# End Source File
# Begin Source File

SOURCE=..\configMS.h
# End Source File
# Begin Source File

SOURCE=..\frontend\get_audio.h
# End Source File
# Begin Source File

SOURCE=.\gpkplotting.h
# End Source File
# Begin Source File

SOURCE=..\frontend\lametime.h
# End Source File
# Begin Source File

SOURCE=..\frontend\parse.h
# End Source File
# Begin Source File

SOURCE=..\frontend\portableio.h
# End Source File
# Begin Source File

SOURCE=..\frontend\timestatus.h
# End Source File
# End Group
# Begin Source File

SOURCE=..\README.WINGTK
# End Source File
# End Target
# End Project
