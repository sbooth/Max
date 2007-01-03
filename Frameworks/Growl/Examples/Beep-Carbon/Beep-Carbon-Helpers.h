/*
 *  Beep-Carbon-Helpers.h
 *  Beep-Carbon
 *
 *  Created by Mac-arena the Bored Zo on Tue Jun 15 2004.
 *  Public domain.
 *
 */

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>

//the order of the types matters. a drag item with the first type in the array
//  will be preferred over an item with the last type, for example. unless the
//  array only has one item, of course. ;)
//the types array is terminated by zero (i.e. '\0\0\0\0').
DragItemRef dragItemWithTypes(const DragRef drag, const OSType *types, UInt16 *outFlavorIndex);

//void lstripnulls(unsigned char **buf, size_t *bufSize);
void convertBytesToFormat(const void *inBytes, const Size inLength, OSType destType, void **outBytes, Size *outLength);

PicHandle scalePictureToRect(PicHandle inPic, const Rect *destRect);
PicHandle scalePictureToImageWell(PicHandle inPic, ControlRef imageWell);
