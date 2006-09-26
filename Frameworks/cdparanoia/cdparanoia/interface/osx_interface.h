#ifndef osx_interface_h
#define osx_interface_h

#include "cdda_interface.h"

int osx_init_drive(cdrom_drive *d);
long osx_read_audio(cdrom_drive *d, void *buffer, long beginsector, long sectors);
cdrom_drive* osx_cdda_identify(const char *dev, int messagedest, char **messages);
cdrom_drive* osx_find_a_cdrom(int messagedest, char **messages);
int osx_cdda_close(cdrom_drive *d);

#endif /* osx_interface_h */
