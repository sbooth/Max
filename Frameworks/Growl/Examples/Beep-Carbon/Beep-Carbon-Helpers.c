/*
 *  Beep-Carbon-Helpers.c
 *  Beep-Carbon
 *
 *  Created by Mac-arena the Bored Zo on Tue Jun 15 2004.
 *  Public domain.
 *
 */

#include "Beep-Carbon-Helpers.h"
#include "Beep-Carbon-Debugging.h"

DragItemRef dragItemWithTypes(const DragRef drag, const OSType *types, UInt16 *outFlavorIndex) {
	DragItemRef item = 0U;
	UInt16 flavorIndexToReturn = 0U;

	if(drag && types) {
		UInt16 numItems, numFlavors;
		OSStatus err;

		err = CountDragItems(drag, &numItems);
		if(err != noErr) numItems = 0U;

		DragItemRef thisItem = 0U;
		UInt16 foundTypeIndex = 0xFFFFU, thisTypeIndex = 0U;

		UInt16 thisItemIndex = 1U;
		while(thisItemIndex <= numItems) {
			err = GetDragItemReferenceNumber(drag, thisItemIndex, &thisItem);
			if(err != noErr) break;

			err = CountDragItemFlavors(drag, thisItem, &numFlavors);
			if(err != noErr) break;

			UInt16 flavorIndex = 1U;
			while(flavorIndex <= numFlavors) {
				OSType flavorType;
				err = GetFlavorType(drag, thisItem, flavorIndex, &flavorType);
				if(err == noErr) {
					while((thisTypeIndex < foundTypeIndex) && types[thisTypeIndex]) {
						if(types[thisTypeIndex] == flavorType) {
							item = thisItem;
							foundTypeIndex = thisTypeIndex;
							flavorIndexToReturn = flavorIndex;
							goto end;
						}
						++thisTypeIndex;
					}
					thisTypeIndex = 0U;
				}
				++flavorIndex;
			} //while(flavorIndex <= numFlavors)
			++thisItemIndex;
		end:
			;
		} //while(thisItemIndex <= numItems)
		if(err != noErr) item = 0U;
	} //if(drag && types)

	if(outFlavorIndex != NULL)
		*outFlavorIndex = flavorIndexToReturn;

	return item;
}

/*
void lstripnulls(unsigned char **buf, size_t *bufSize) {
	size_t i   = 0U;
	size_t max = 512U > *bufSize ? 512U : *bufSize;
	while(i < max)
		if((*buf)[i])
			break;
		else
			++i;
	memmove((*buf), &(*buf)[i], max -= i);
	*bufSize -= i;
	(*buf) = realloc((*buf), *bufSize);
}
*/

void convertBytesToFormat(const void *inBytes, const Size inLength, OSType destType, void **outBytes, Size *outLength) {
	unsigned long ULLength = 0UL;
	void *buf = NULL;
	if(outBytes && outLength && inLength && inBytes) {
		GraphicsImportComponent importer;
		OSStatus err;

		Handle inHandle = NULL, outHandle = NULL;

		//this next bit is weird. blame QuickTime.
		//create the Handle (stashed in inHandle temporarily) which will hold
		//  the output data, and wrap it in another Handle (outHandle).
		outHandle = NewHandle(sizeof(Handle));
		if(outHandle) {
			HLock(outHandle);
			Handle *hptr = (Handle *)*outHandle;
			*hptr = NewHandle(0);
			DEBUG_printf1("Handle in outHandle: %p\n", *hptr);
			HUnlock(outHandle);
		}

		//this PointerDataRefRecord describes our input.
		PointerDataRefRecord pdrr;
		pdrr.data       = (Ptr)inBytes;
		pdrr.dataLength = inLength;
		PtrToHand( &pdrr,      &inHandle, sizeof(pdrr));
		{
			PointerDataRefRecord *pdrrptr;
			HLock(inHandle);
			pdrrptr = (PointerDataRefRecord *)*inHandle;
			DEBUG_printf2("PDRR in inHandle: data %p; dataLength %u\n", pdrrptr->data, pdrrptr->dataLength);
			HUnlock(inHandle);
		}

		//okay, our I/O Handles should be all set up now. do the job.

		if(inHandle && outHandle) {
			DEBUG_printf6("inHandle %p %p %p; outHandle %p %p %p\n", inHandle, *inHandle, *(Handle *)*inHandle, outHandle, *outHandle, *(Handle *)*outHandle);
			err = GetGraphicsImporterForDataRef(inHandle, PointerDataHandlerSubType, &importer);
			DEBUG_printf1("GetGraphicsImporterForDataRef: %i\n", (int)err);
//			if(err != noErr) break;

			ImageDescriptionHandle inDesc = NULL;
			err = GraphicsImportGetImageDescription(importer, &inDesc);
			DEBUG_printf1("GraphicsImportGetImageDescription: %i\n", (int)err);

#ifdef DEBUG
			DEBUG_print("Converting to... ");
			CFStringRef typeStr = CreateTypeStringWithOSType(destType);
			CFShow(typeStr);
			CFRelease(typeStr);
#endif

			//ImageDescriptionHandle outDesc = NewHandle(0);
			GraphicsExportComponent exporter;
			err = OpenADefaultComponent(GraphicsExporterComponentType, destType, &exporter);
			DEBUG_printf1("OpenADefaultComponent: %i\n", (int)err);

			err = GraphicsExportSetInputGraphicsImporter(exporter, importer);
			DEBUG_printf1("GraphicsExportSetInputGraphicsImporter: %i\n", (int)err);
//			err = GraphicsExportSetCompressionQuality(exporter, codecMaxQuality);
//			DEBUG_printf1("GraphicsExportSetCompressionQuality: %i\n", (int)err);
			err = GraphicsExportSetOutputDataReference(exporter, outHandle, HandleDataHandlerSubType);
			DEBUG_printf1("GraphicsExportSetOutputDataReference: %i\n", (int)err);
			err = GraphicsExportDoExport(exporter, &ULLength);
			DEBUG_printf1("GraphicsExportDoExport: %i\n", (int)err);

			CloseComponent(importer);
			CloseComponent(exporter);
		} //if(inHandle && outHandle)
		if(inHandle) DisposeHandle(inHandle);

		DEBUG_printf2("ULLength %lu; GetHandleSize(outHandle) %u\n", ULLength, (unsigned)GetHandleSize(outHandle));
		if(ULLength && outHandle) {
			buf = malloc(ULLength);
			if(buf) {
				//QuickTime returns a PICT file. we want to return PICT data.
				//so if our output type is PICT, lop off the 512 nuls QT inserts
				//  before the PICT header.
				size_t offset = 512U * (destType == typePict);
				HLock(outHandle);
				Handle outHandle2 = *(Handle *)*outHandle;
				DEBUG_printf1("GetHandleSize(outHandle2) %u\n", (unsigned)GetHandleSize(outHandle2));
				HLock(outHandle2);
				memcpy(buf, &((*outHandle2)[offset]), ULLength -= offset);

#ifdef DEBUG
				PicPtr pict = (PicPtr)*outHandle2;
				DEBUG_printf5("size: %hi; rect { top %hi; left %hi; bottom %hi; right %hi }\n", pict->picSize, pict->picFrame.top, pict->picFrame.left, pict->picFrame.bottom, pict->picFrame.right);
#endif

				HUnlock(outHandle2);
				HUnlock(outHandle);
			}
		}
		HLock(outHandle);
		if(*(Handle *)*outHandle) DisposeHandle(*(Handle *)*outHandle);
		HUnlock(outHandle);
		if(outHandle) DisposeHandle(outHandle);
	}
	if(outBytes)
		*outBytes  = buf;
	if(outLength)
		*outLength = ULLength;
} //void convertBytesToFormat(const void *inBytes, const Size inLength, OSType destType, void **outBytes, Size *outLength)

PicHandle scalePictureToRect(PicHandle inPic, const Rect *destRect) {
	const Fixed dpi_72 = Long2Fix(72L);
	OpenCPicParams params = { *destRect, /*hRes*/ dpi_72, /*vRes*/ dpi_72, /*version*/ -2, /*reserved1*/ 0, /*reserved2*/ 0 };
	PicHandle newPic = OpenCPicture(&params);
	if(newPic) {
		DrawPicture(inPic, destRect);
		ClosePicture();
	}
	return newPic;
}
PicHandle scalePictureToImageWell(PicHandle inPic, ControlRef imageWell) {
	Rect bounds;
	GetControlBounds(imageWell, &bounds);

	//we don't want to draw over the image well's border.
	{
		SInt32 inset;
		OSStatus err = GetThemeMetric(kThemeMetricImageWellThickness, &inset);
		if(err != noErr)
			inset = 5;
		bounds.top    += inset;
		bounds.left   += inset;
		bounds.bottom -= inset;
		bounds.right  -= inset;
	}

	//we don't want to scale the picture up if it's smaller than the well.
	//so we adjust our destination rect if necessary to avoid that.
	{
		short ctlWidth,  pictWidth;
		short ctlHeight, pictHeight;

		ctlWidth  = bounds.right  - bounds.left;
		ctlHeight = bounds.bottom - bounds.top;
		HLock((Handle)inPic);
		PicPtr pict = *inPic;
		pictWidth  = pict->picFrame.right  - pict->picFrame.left;
		pictHeight = pict->picFrame.bottom - pict->picFrame.top;
		HUnlock((Handle)inPic);

		float delta;
		if(pictWidth < ctlWidth) {
			delta = ctlWidth - pictWidth;
			delta /= 2.0f;
			bounds.left  += delta;
			bounds.right -= ceilf(delta);
		}
		if(pictHeight < ctlHeight) {
			delta = ctlHeight - pictHeight;
			delta /= 2.0f;
			bounds.top    += delta;
			bounds.bottom -= ceilf(delta);
		}
	} 

	return scalePictureToRect(inPic, &bounds);
}
