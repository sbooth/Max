/*
 *  GrowlInstallationPrompt-Carbon.c
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on 2005-05-07.
 *  Copyright 2005 The Growl Project. All rights reserved.
 *
 */

#include "GrowlInstallationPrompt-Carbon.h"
#include "GrowlApplicationBridge-Carbon.h"
#include "GrowlDefines.h"

#include <QuickTime/QuickTime.h>
#include <alloca.h>
#include <unistd.h>
#include <limits.h>
#include <sys/wait.h>

//see GrowlApplicationBridge-Carbon.c for information about why NSLog is declared here.

extern void NSLog(CFStringRef format, ...);

#pragma mark -

#define GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER CFSTR("com.growl.growlwithinstallerframework")
#define GROWL_SIGNATURE FOUR_CHAR_CODE('GRRR')

enum {
	OKButtonIDNumber      = 1000,
	cancelButtonIDNumber  = 1001,
	imageViewIDNumber     = 3000,
	textViewIDNumber      = 4000,
	chasingArrowsIDNumber = 5000,
};

//for associating the update version with the window.
#define GIPC_UPDATE_VERSION FOUR_CHAR_CODE('UPDV')

#define GROWL_PREFPANE_NAME					CFSTR("Growl.prefPane")

#pragma mark -

//from GrowlApplicationBridge.
extern void _userChoseToInstallGrowl(void);
extern void _userChoseNotToInstallGrowl(void);

#pragma mark -

static const long minimumOSXVersionForGrowl = 0x1030L; //Panther (10.3.0)

static Boolean _checkOSXVersion(void) {
	long OSXVersion = 0L;
	OSStatus err = Gestalt(gestaltSystemVersion, &OSXVersion);
	if (err != noErr) {
		NSLog(CFSTR("WARNING in GrowlInstallationPrompt: could not get Mac OS X version (selector = %x); got error code %li (will show the installation prompt anyway)"), (unsigned)gestaltSystemVersion, (long)err);
		//we proceed anyway, on the theory that it is better to show the installation prompt when inappropriate than to suppress it when not.
		OSXVersion = minimumOSXVersionForGrowl;
	}
	return (OSXVersion >= minimumOSXVersionForGrowl);
}

#pragma mark -

static OSStatus _handleCommandInWindow(EventHandlerCallRef nextHandler, EventRef event, void *refcon);

static OSStatus _fillOutTextInWindow(WindowRef window, Boolean isUpdate);
static OSStatus _fillOutIconInWindow(WindowRef window);

/*!	@function	_installGrowl
 *	@abstract	Does the real work of installing Growl.
 *	@discussion	Copies Growl.prefpane.zip, unzips it, and launches the prefpane
 *	 with System Preferences to get it installed.
 */
static OSStatus _installGrowl(CFRunLoopRef mainThreadRunLoop);

#pragma mark -

//these are not static because they are to be called by GrowlApplicationBridge.
OSStatus _Growl_ShowInstallationPrompt(void);
OSStatus _Growl_ShowUpdatePromptForVersion(CFStringRef updateVersion);

#pragma mark -

OSStatus _Growl_ShowInstallationPrompt(void) {
	return _Growl_ShowUpdatePromptForVersion(NULL);
}

OSStatus _Growl_ShowUpdatePromptForVersion(CFStringRef updateVersion) {
	OSStatus err = noErr;

	if (_checkOSXVersion()) {
		CFBundleRef bundle = CFBundleGetBundleWithIdentifier(GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER);
		if (!bundle)
			NSLog(CFSTR("GrowlInstallationPrompt: could not locate framework bundle (forget about installing Growl); had looked for bundle with identifier '%@'"), GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER);
		else {
			IBNibRef nib = NULL;
			err = CreateNibReferenceWithCFBundle(bundle, CFSTR("GrowlInstallationPrompt-Carbon"), &nib);
			if (err != noErr) {
				NSLog(CFSTR("GrowlInstallationPrompt: could not obtain nib: CreateNibReferenceWithCFBundle(%@, %@) returned %li"), bundle, CFSTR("GrowlInstallationPrompt-Carbon"), (long)err);
			} else {
				WindowRef window = NULL;

				err = CreateWindowFromNib(nib, CFSTR("Installation prompt"), &window);
				DisposeNibReference(nib);

				if (err != noErr) {
					NSLog(CFSTR("GrowlInstallationPrompt: could not obtain window from nib: CreateWindowFromNib(%p, %@) returned %li"), nib, CFSTR("Installation prompt"), (long)err);
				} else {
					OSStatus fillOutTextErr = _fillOutTextInWindow(window, (updateVersion != nil));
					OSStatus fillOutIconErr = _fillOutIconInWindow(window);

					err = (fillOutTextErr != noErr) ? fillOutTextErr : (fillOutIconErr != noErr) ? fillOutIconErr : noErr;
					if (err == noErr) {
						if (updateVersion) {
							//store the update version on the window.
							updateVersion = CFRetain(updateVersion);
							err = SetWindowProperty(window,
													GROWL_SIGNATURE,
													GIPC_UPDATE_VERSION,
													sizeof(updateVersion),
													&updateVersion);
							if (err != noErr)
								NSLog(CFSTR("GrowlInstallationPrompt: SetWindowProperty returned %li"), (long)err);
						}

						EventHandlerUPP handlerUPP = NewEventHandlerUPP(_handleCommandInWindow);

						struct EventTypeSpec types[] = {
							{ .eventClass = kEventClassCommand, .eventKind = kEventCommandProcess },
						};

						EventHandlerRef handler = NULL;
						err = InstallWindowEventHandler(window,
														handlerUPP,
														GetEventTypeCount(types),
														types,
														/*refcon*/ window,
														&handler);
						if (err != noErr)
							NSLog(CFSTR("GrowlInstallationPrompt: InstallWindowEventHandler returned %li"), (long)err);
						else {
							HIViewID chasingArrowsID = { GROWL_SIGNATURE, chasingArrowsIDNumber };
							HIViewRef chasingArrows = NULL;
							
							//stop and hide the chasing arrows, until the user clicks Install.
							OSStatus chasingArrowsErr = HIViewFindByID(HIViewGetRoot(window), chasingArrowsID, &chasingArrows);
							if (chasingArrowsErr == noErr) {
								Boolean truth = false;
								SetControlData(chasingArrows,
											   kControlEntireControl,
											   kControlChasingArrowsAnimatingTag,
											   sizeof(truth),
											   &truth);
								HIViewSetVisible(chasingArrows, false);
							}

							SelectWindow(window);
							ShowWindow(window);

							err = RunAppModalLoopForWindow(window);
							if (err != noErr)
								NSLog(CFSTR("GrowlInstallationPrompt: RunAppModalLoopForWindow(%p) returned %li"), window, (long)err);

							RemoveEventHandler(handler);
						}
						DisposeEventHandlerUPP(handlerUPP);
					}

					ReleaseWindow(window);
				}
			}
		}
	}

	return err;
}

#pragma mark -

static OSStatus _handleCommandInWindow(EventHandlerCallRef nextHandler, EventRef event, void *refcon) {
#pragma unused(nextHandler)
	OSStatus err = eventNotHandledErr;

	EventClass class = GetEventClass(event);
	if (class == kEventClassCommand) {
		EventKind kind = GetEventKind(event);
		if (kind == kEventCommandProcess) {
			struct HICommandExtended cmd;
			err = GetEventParameter(event,
									kEventParamDirectObject,
									typeHICommand,
									/*outActualType*/ NULL,
									sizeof(cmd),
									/*outActualSize*/ NULL,
									&cmd);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: GetEventParameter returned %li; cmd is %@"), (long)err, CreateTypeStringWithOSType(cmd.commandID));
			else {
				CFStringRef updateVersion = NULL;
				err = GetWindowProperty(/*window*/ refcon,
										GROWL_SIGNATURE,
										GIPC_UPDATE_VERSION,
										sizeof(updateVersion),
										/*actualSize*/ NULL,
										&updateVersion);
				if ((err != noErr) && (err != errWindowPropertyNotFound))
					NSLog(CFSTR("GrowlInstallationPrompt: cannot retrieve the update version (if any) from the confirmation dialog: GetWindowProperty returned %li"), (long)err);

				WindowRef window = refcon;

				switch(cmd.commandID) {
					case kHICommandOK:
#pragma mark OK button
						/*tell GAB so it can register for GROWL_IS_READY.
						 *(note that this needs to be done for both updates and
						 *	clean installations.)
						 */
						_userChoseToInstallGrowl();

						HIViewID \
							chasingArrowsID = { GROWL_SIGNATURE, chasingArrowsIDNumber },
							OKButtonID      = { GROWL_SIGNATURE,      OKButtonIDNumber },
							cancelButtonID  = { GROWL_SIGNATURE,  cancelButtonIDNumber };
						HIViewRef rootView = HIViewGetRoot(window), chasingArrows = NULL, OKButton = NULL, cancelButton = NULL;

						//start and show the chasing arrows (optional, but preferred).
						OSStatus chasingArrowsErr = HIViewFindByID(rootView, chasingArrowsID, &chasingArrows);
						if (chasingArrowsErr == noErr) {
							Boolean truth = true;
							SetControlData(chasingArrows,
										   kControlEntireControl,
										   kControlChasingArrowsAnimatingTag,
										   sizeof(truth),
										   &truth);
							HIViewSetVisible(chasingArrows, true);
						}
						//disable the OK and Cancel buttons (optional, but preferred).
						OSStatus OKButtonErr = HIViewFindByID(rootView, OKButtonID, &OKButton);
						if (OKButtonErr == noErr)
							EnableControl(OKButton);
						OSStatus cancelButtonErr = HIViewFindByID(rootView, cancelButtonID, &cancelButton);
						if (cancelButtonErr == noErr)
							EnableControl(cancelButton);

						MPTaskID task = NULL;
						err = MPCreateTask((TaskProc)_installGrowl,
										   CFRunLoopGetCurrent(), //&context,
										   /*stackSize*/ 0U,
										   /*notifyQueue*/ NULL,
										   /*terminationParameter1,2*/ NULL, NULL,
										   /*options*/ 0U,
										   &task);
						/*XXX figure out how to handle errors returned by
						 *	MPCreateTask, while ignoring errors returned by
						 *	_installGrowl
						 */

						//run the run loop, so that the chasing arrows animate.
						CFRunLoopRun(); //terminated by the work thread

						//stop and hide the chasing arrows, if appropriate.
						if (chasingArrowsErr == noErr) {
							Boolean truth = false;
							SetControlData(chasingArrows,
										   kControlEntireControl,
										   kControlChasingArrowsAnimatingTag,
										   sizeof(truth),
										   &truth);
							HIViewSetVisible(chasingArrows, false);
							//make sure we hide the chasing arrows before we hide the window.
							HIViewRender(chasingArrows);
							//and make sure the user can see it.
							usleep(1000000U); //1/10 sec
						}

						HideWindow(window);

						//reenable the OK and Cancel buttons (optional, but preferred).
						if (OKButtonErr == noErr)
							EnableControl(OKButton);
						if (cancelButtonErr == noErr)
							EnableControl(cancelButton);

						if(!err) err = chasingArrowsErr;
						//skip over the Cancel-specific code
						goto common;

					case kHICommandCancel:;
#pragma mark Cancel button
						//if there is an update version, this is the time to release it.
						//if there is no update version, then this was an install request, and we need to tell GAB that it was cancelled.
						if (updateVersion)
							CFRelease(updateVersion);
						else
							_userChoseNotToInstallGrowl();

					common:
#pragma mark Common to OK and Cancel buttons
						err = QuitAppModalLoopForWindow(refcon);
						break;

					case 'NO!!':;
#pragma mark Dont Ask Again
						//the 'Don't ask again' checkbox.
						ControlRef     checkbox = cmd.source.control;
						Boolean    dontAskAgain = (GetControl32BitValue(checkbox) != kControlCheckBoxUncheckedValue);

						CFStringRef         key = NULL;
						CFPropertyListRef value = NULL;

						if (updateVersion) {
							key = CFSTR("Growl Update:Do Not Prompt Again:Last Version");
							if (dontAskAgain)
								value = updateVersion;
						} else {
							CFBooleanRef bools[] = { kCFBooleanFalse, kCFBooleanTrue };
							key   = CFSTR("Growl Installation:Do Not Prompt Again");
							value = bools[dontAskAgain];
						}

						CFPreferencesSetAppValue(key, value, kCFPreferencesCurrentApplication);
						CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
						break;

					default:
						err = eventNotHandledErr;
						break;
				} //switch(cmd.commandID)
			} //if (err == noErr) (GetEventParameter)
		} //if (kind == kEventCommandProcess)
	} //if (class == kEventClassCommand)

	return err;
}

static OSStatus _fillOutTextInWindow(WindowRef window, Boolean isUpdate) {
	OSStatus err = noErr;

	HIViewRef textView = NULL;
	HIViewID textViewID = {
		.signature = GROWL_SIGNATURE,
		.id = textViewIDNumber,
	};
	err = HIViewFindByID(HIViewGetRoot(window),
						 textViewID,
						 &textView);
	if (err != noErr) {
		NSLog(CFSTR("GrowlInstallationPrompt: could not obtain text view in confirmation dialog: HIViewFindByID returned %li"), (long)err);
	} else {
		CFBundleRef bundle = CFBundleGetBundleWithIdentifier(GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER);

		struct Growl_Delegate *delegate = Growl_GetDelegate();

		CFStringRef title = NULL;
		if (delegate) title = isUpdate ? delegate->growlUpdateWindowTitle : delegate->growlInstallationWindowTitle;
		if (title) {
			title = CFRetain(title);
		} else {
			if (isUpdate) {
				title = CFCopyLocalizedStringFromTableInBundle(CFSTR("Growl Update Available"),
															   CFSTR("GrowlInstallation"),
															   bundle,
															   /*comment*/ NULL);
				
			} else {
				title = CFCopyLocalizedStringFromTableInBundle(CFSTR("Growl Installation Recommended"),
															   CFSTR("GrowlInstallation"),
															   bundle,
															   /*comment*/ NULL);
			}
		}

		if (title) {
			err = SetWindowTitleWithCFString(window, title);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not set title of confirmation dialog: SetWindowTitle returned %li"), (long)err);
		}

		CFStringRef message = NULL;
		if (delegate) message = isUpdate ? delegate->growlUpdateInformation : delegate->growlInstallationInformation;
		if (message) {
			message = CFRetain(message);
		} else {
			if (isUpdate) {
				message = CFCopyLocalizedStringFromTableInBundle(CFSTR("This program displays information via Growl, a centralized notification system.  A version of Growl is currently installed, but this program includes an updated version of Growl.  It is strongly recommended that you update now.  No download is required."),
																 CFSTR("GrowlInstallation"),
																 bundle,
																 /*comment*/ NULL);
			} else {
				message = CFCopyLocalizedStringFromTableInBundle(CFSTR("This program displays information via Growl, a centralized notification system.  Growl is not currently installed; to see Growl notifications from this and other applications, you must install it.  No download is required."),
																 CFSTR("GrowlInstallation"),
																 bundle,
																 /*comment*/ NULL);
			}
		}

		if (!title)   title   = CFSTR("");
		if (!message) message = CFSTR("");

		CFIndex titleLength = CFStringGetLength(title), messageLength = CFStringGetLength(message);

		CFStringRef joiner = titleLength ? CFSTR("\n\n") : CFSTR("");

		CFMutableStringRef mCompleteText = CFStringCreateMutable(kCFAllocatorDefault, titleLength + CFStringGetLength(joiner) + messageLength);
		CFStringAppend(mCompleteText, title);
		CFStringAppend(mCompleteText, joiner);
		CFStringAppend(mCompleteText, message);

		CFStringRef completeText = mCompleteText;

		TXNObject mlte = HITextViewGetTXNObject(textView);

		//make sure we can modify the contents of the view but the user can't
		{
			enum { numControls = 2U };
			TXNControlTag controlTags[numControls] = {
				kTXNIOPrivilegesTag, kTXNNoUserIOTag,
			};
			TXNControlData controlData[numControls] = {
				{ .uValue = kTXNReadWrite },
				{ .uValue = kTXNReadOnly },
			};
			err = TXNSetTXNObjectControls(mlte,
										  /*iClearAll*/ false,
										  numControls,
										  controlTags,
										  controlData);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not set permissions of text view in confirmation dialog: TXNSetTXNObjectControls returned %li"), (long)err);
		}

		//put the text into the text view
		{
			CFIndex numBytes = 0;
			CFRange range = { 0, CFStringGetLength(completeText) };
			CFStringGetBytes(completeText,
							 range,
							 kCFStringEncodingUnicode,
							 /*lossByte*/ 0,
							 /*isExternalRepresentation*/ false,
							 /*buffer*/ NULL,
							 /*maxBufLen*/ 0,
							 &numBytes);

			UTF16Char *buf = malloc(numBytes);
			if (!buf) return memFullErr;

			CFStringGetBytes(completeText,
							 range,
							 kCFStringEncodingUnicode,
							 /*lossByte*/ 0,
							 /*isExternalRepresentation*/ false,
							 (UInt8 *)buf,
							 numBytes,
							 &numBytes);

			err = TXNSetData(mlte,
							 kTXNUnicodeTextData,
							 buf,
							 numBytes,
							 kTXNStartOffset,
							 kTXNEndOffset);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not set contents of text view in confirmation dialog: TXNSetData returned %li (string was '%@')"), (long)err, completeText);
		}

		//set up MLTE the fonts
		{
			Str255 fontName = "\pLucida Grande";
			SInt16 fontSize = 13;
			Style style = normal;
			err = GetThemeFont(kThemeSystemFont,
							   smCurrentScript,
							   fontName,
							   &fontSize,
							   &style);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not obtain correct font for text view in confirmation dialog: GetThemeFont returned %li"), (long)err);

			FMFontFamily family = FMGetFontFamilyFromName(fontName);

			struct TXNTypeAttributes attrs[] = {
				{
					.tag  = kTXNQDFontFamilyIDAttribute,
					.size = kTXNQDFontFamilyIDAttributeSize,
					.data = { .dataValue = family }
				},
				{
					.tag  = kTXNQDFontSizeAttribute,
					.size = kTXNQDFontSizeAttributeSize,
					.data = { .dataValue = Long2Fix(fontSize) }
				},
				{
					.tag  = kATSUQDBoldfaceTag,
					.size = sizeof(Boolean),
					.data = { .dataValue = true }
				},
			};

			err = TXNSetTypeAttributes(mlte,
									   2U, //exclude bold
									   attrs,
									   titleLength,
									   kTXNEndOffset);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not set font of informative text in confirmation dialog: TXNSetTypeAttributes returned %li"), (long)err);
			err = TXNSetTypeAttributes(mlte,
									   3U, //include bold
									   attrs,
									   kTXNStartOffset,
									   titleLength);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not set font of message text in confirmation dialog: TXNSetTypeAttributes returned %li"), (long)err);
		}
	}

	return err;
}

static OSStatus _fillOutIconInWindow(WindowRef window) {
	OSStatus err = noErr;

	HIViewRef imageView = NULL;
	HIViewID imageViewID = {
		.signature = GROWL_SIGNATURE,
		.id = imageViewIDNumber,
	};
	err = HIViewFindByID(HIViewGetRoot(window),
						 imageViewID,
						 &imageView);
	if (err != noErr) {
		NSLog(CFSTR("GrowlInstallationPrompt: could not obtain image view in confirmation dialog: HIViewFindByID returned %li"), (long)err);
	} else {
		struct ProcessInfoRec processInfo;
		const struct ProcessSerialNumber psn = { 0, kCurrentProcess };
		err = GetProcessInformation(&psn, &processInfo);
		if (err != noErr)
			NSLog(CFSTR("GrowlInstallationPrompt: could not determine application signature (in order to get application icon): GetProcessInformation returned %li"), (long)err);
		else {
			IconRef icon = NULL;
			err = GetIconRef(kOnSystemDisk, processInfo.processSignature, 'APPL', &icon);
			if (err != noErr)
				NSLog(CFSTR("GrowlInstallationPrompt: could not get application icon: GetIconRef provided icon %p and returned %li"), icon, (long)err);
			else {
				HIRect bounds;
				union {
					CGSize cg;
					HISize hi;
				} size;
				err = HIViewGetBounds(imageView, &bounds);
				if (err == noErr) {
					size.hi = bounds.size;
					size.hi.width  = floorf(size.hi.width);
					size.hi.height = floorf(size.hi.height);
				} else
					size.cg = CGSizeMake(64.0f, 64.0f);

				CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
				if (!colorSpace)
					NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: CGColorSpaceCreateDeviceRGB returned NULL"));
				else {
					static const size_t bitsPerComponent = 8U;
					static const size_t bitsPerPixel     = 32U;
					const size_t bytesPerRow      = 4U * size.cg.width;

					size_t bufsize = bytesPerRow * size.cg.height;
					u_int32_t *buf = malloc(bufsize);
					if (!buf)
						NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: malloc returned NULL"));
					else {
						CGContextRef context = CGBitmapContextCreate(buf,
																	 size.cg.width,
																	 size.cg.height,
																	 bitsPerComponent,
																	 bytesPerRow,
																	 colorSpace,
																	 kCGImageAlphaPremultipliedFirst);
						if (!context)
							NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: CGBitmapContextCreate returned %p"), context);
						else {
							CGRect rect = { { 0.0f, 0.0f }, size.cg };
							err = PlotIconRefInContext(context,
													   &rect,
													   kAlignAbsoluteCenter,
													   kTransformNone,
													   /*inLabelColor*/ NULL,
													   kPlotIconRefNormalFlags,
													   icon);
							if (err != noErr)
								NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: PlotIconRefInContext returned %li"), (long)err);
							else {
								CGDataProviderRef provider = CGDataProviderCreateWithData(/*refcon*/ NULL,
																						  buf,
																						  bufsize,
																						  /*releaseData*/ NULL);
								if (!provider)
									NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: CGDataProviderCreateWithData returned %p"), provider);
								else {
									CGImageRef image = CGImageCreate(size.cg.width,
																	 size.cg.height,
																	 bitsPerComponent,
																	 bitsPerPixel,
																	 bytesPerRow,
																	 colorSpace,
																	 kCGImageAlphaFirst,
																	 provider,
																	 /*decode*/ NULL,
																	 /*shouldInterpolate*/ false,
																	 kCGRenderingIntentDefault);
									if (!image) {
										NSLog(CFSTR("GrowlInstallationPrompt: could not convert application icon for display: CGImageCreate returned %p"), provider);
									} else {
										err = HIImageViewSetImage(imageView, image);

										CFRelease(image);

										if (err != noErr)
											NSLog(CFSTR("GrowlInstallationPrompt: could not display application icon: HIImageViewSetImage returned %li"), (long)err);
									} //if (image)

									CFRelease(provider);
								} //if (provider)

								CFRelease(context);
							} //if (err == noErr) (PlotIconRefInContext)
						} //if (context)
					} //if (buf)
				} //if (colorSpace)

				ReleaseIconRef(icon);
			} //if (err == noErr) (GetIconRef)
		} //if (err == noErr) (GetProcessInformation)
	} //if (err == noErr) (HIViewFindByID)

	return err;
}

#include "CFGrowlAdditions.h"

static OSStatus _installGrowl(CFRunLoopRef mainThreadRunLoop) {
	OSStatus err = noErr;

	//get temporary directory
	CFURLRef tempDir = copyTemporaryFolderURL();

	if (tempDir) {
		//create that directory
		if (!createURLByMakingDirectoryAtURLWithName(tempDir, /*name*/ NULL))
			NSLog(CFSTR("GrowlInstallationPrompt: could not make directory at %@"), tempDir);
		else {
			//append "GrowlInstallations" path component
			CFURLRef installerDir = createURLByMakingDirectoryAtURLWithName(tempDir, CFSTR("GrowlInstallations"));

			if (!installerDir)
				NSLog(CFSTR("GrowlInstallationPrompt: could not make directory at %@ named '%@'"), tempDir, CFSTR("GrowlInstallations"));
			else {
				//append UUID
				CFUUIDRef UUID = CFUUIDCreate(kCFAllocatorDefault);

				if (!UUID)
					NSLog(CFSTR("GrowlInstallationPrompt: could not create UUID for temporary directory"));
				else {
					CFStringRef UUIDString = CFUUIDCreateString(kCFAllocatorDefault, UUID);
					CFRelease(UUID);

					if (!UUIDString)
						NSLog(CFSTR("GrowlInstallationPrompt: could not create string representation of UUID"));
					else {
						CFURLRef installerDirWithUUID = createURLByMakingDirectoryAtURLWithName(installerDir, UUIDString);
						if (!installerDirWithUUID)
							NSLog(CFSTR("GrowlInstallationPrompt: could not make directory at %@ with UUID '%@'"), installerDir, UUIDString);
						else {
							//get framework bundle
							CFBundleRef bundle = CFBundleGetBundleWithIdentifier(GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER);

							if (!bundle)
								NSLog(CFSTR("GrowlInstallationPrompt: could not obtain framework bundle with identifier '%@'"), GROWL_WITHINSTALLER_FRAMEWORK_IDENTIFIER);
							else {
								//get zip file from it
								CFURLRef zipFile = CFBundleCopyResourceURL(bundle,
																		   GROWL_PREFPANE_NAME,
																		   CFSTR("zip"),
																		   /*subDirName*/ NULL);

								if (!zipFile)
									NSLog(CFSTR("GrowlInstallationPrompt: could not find resource named %@.%@ in framework bundle %@"), GROWL_PREFPANE_NAME, CFSTR("zip"), bundle);
								else {
									//copy zip file to temporary directory
									//XXX - if this copy fails, try to unzip it in its original location, and if that succeeds, delete the prefpane after installation (needs to replicate rm -r)
									CFURLRef newZipFile = createURLByCopyingFileFromURLToDirectoryURL(zipFile, installerDirWithUUID);
									if (newZipFile) {
										CFRelease(zipFile);
										zipFile = newZipFile;
									}

									char *zipFilePath      = malloc(PATH_MAX);
									char *installerDirPath = malloc(PATH_MAX);

									if (!zipFilePath)
										NSLog(CFSTR("GrowlInstallationPrompt: could not create buffer of %lu bytes for zip file path"), (unsigned long)PATH_MAX);
									if (!installerDirPath)
										NSLog(CFSTR("GrowlInstallationPrompt: could not create buffer of %lu bytes for installation directory path"), (unsigned long)PATH_MAX);

									if (zipFilePath && installerDirPath) {
										CFURLGetFileSystemRepresentation(zipFile, /*resolveAgainstBase*/ true, (unsigned char *)zipFilePath, PATH_MAX);
										CFURLGetFileSystemRepresentation(installerDirWithUUID, /*resolveAgainstBase*/ true, (unsigned char *)installerDirPath, PATH_MAX);

										char *args[7] = {
											NULL, NULL, NULL, NULL,
											NULL, NULL, NULL,
										};

										//find BOMArchiveHelper
										FSRef bomArchiveHelperRef;
										static const char bomArchiveHelperPath[] = "/System/Library/CoreServices/BOMArchiveHelper.app/Contents/MacOS/BOMArchiveHelper";
										err = FSPathMakeRef((const unsigned char *)bomArchiveHelperPath, &bomArchiveHelperRef, /*isDirectory*/ false);
										if (err == noErr) {
											//BOMArchiveHelper exists - use it

											args[0] = (char *)bomArchiveHelperPath;
											args[1] = zipFilePath;
											args[2] = NULL;
										} else {
											//BOMArchiveHelper doesn't exist or we couldn't get it - use unzip and hope for the best
											if (err != fnfErr)
												NSLog(CFSTR("GrowlInstallationPrompt: could not get FSRef for BOMArchiveHelper: FSPathMakeRef returned %li (will try using unzip instead)"), (long)err);

											args[0] = "/usr/bin/unzip";
											args[1] = "-o"; //overwrite
											args[2] = "-q"; //quiet (don't flood the Console log)
											args[3] = zipFilePath;
											CFURLGetFileSystemRepresentation(zipFile, /*resolveAgainstBase*/ true, (unsigned char *)zipFilePath, PATH_MAX);
											args[4] = "-d"; //destination directory follows
											args[5] = installerDirPath;
											args[6] = NULL;
										}

										//launch whatever we're using
										int status = -1;
										pid_t pid = fork();
										if (pid < 0)
											NSLog(CFSTR("GrowlInstallationPrompt: could not fork to run %s: %s"), args[0], strerror(errno));
										else if (pid == 0)
											execvp((const char *)(args[0]), (char *const *)args);
										else {
											//wait for the unzipper to exit
											while (waitpid(pid, &status, /*options*/ 0) != pid)
												usleep(10000U); //1/100 sec
										}

										if (WEXITSTATUS(status) == 0) {
											//post GROWL_SHUTDOWN
											CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(),
																				 GROWL_SHUTDOWN,
																				 /*object*/ NULL,
																				 /*userInfo*/ NULL,
																				 /*deliverImmediately*/ false);

											//set a register-when-Growl-is-ready flag in GABC
											Growl_SetWillRegisterWhenGrowlIsReady(true);

											//obtain location of prefpane
											CFURLRef prefPane = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault,
																									  installerDirWithUUID,
																									  GROWL_PREFPANE_NAME,
																									  /*isDirectory*/ true);
											if (!prefPane)
												NSLog(CFSTR("GrowlInstallationPrompt: prefpane didn't exist after we unzipped it (?!?!): installation directory is %@ and we looked for a prefpane named %@"), installerDirWithUUID, GROWL_PREFPANE_NAME);
											else {
												//open it with LS
												err = LSOpenCFURLRef(prefPane, /*outLaunchedURL*/ NULL);
												if (err != noErr)
													NSLog(CFSTR("GrowlInstallationPrompt: could not launch the prefpane because LSOpenCFURLRef, passed %@, returned %li"), prefPane, (long)err);
											} //if (prefPane)
										} //if (WEXITSTATUS(status) == 0)
									} //if (zipFilePath && installerDirPath)

									//remember that free(NULL) is a no-op in Mac OS X. (so sayeth free(3) and QA1259.)
									free(zipFilePath);
									free(installerDirPath);

									CFRelease(zipFile);
								} //if (zipFile)
							} //if (bundle)

							CFRelease(installerDirWithUUID);
						} //if ((installerDirWithUUID = createURLByMakingDirectoryAtURLWithName(installerDir, UUIDString)))

						CFRelease(UUIDString);
					} //if (UUIDString)

					//UUID is released above
				} //if (UUID)

				CFRelease(installerDir);
			} //if (installerDir = createURLByMakingDirectoryAtURLWithName(tempDir, CFSTR("GrowlInstallations")))

		} //if (createURLByMakingDirectoryAtURLWithName(tempDir, /*name*/ NULL))
		CFRelease(tempDir);
	} //if (tempDir)

	if (err != noErr) {
#warning XXX - show this to the user; do not just log it.
		NSLog(CFSTR("GrowlInstallationPrompt: Growl was not successfully installed"));
	}

	if(mainThreadRunLoop)
		CFRunLoopStop(mainThreadRunLoop);

	return err;
}
