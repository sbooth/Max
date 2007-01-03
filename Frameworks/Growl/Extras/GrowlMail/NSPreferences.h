/*
 Copyright (c) The Growl Project, 2004-2005
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
 *  NSPreferences.h
 *  GrowlMail
 *
 *  Created by Ingmar Stein on 30.10.04.
 *  Copyright 2004-2005 The Growl Project. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

@interface NSPreferences:NSObject
{
	NSWindow *_preferencesPanel;
	NSBox *_preferenceBox;
	NSMatrix *_moduleMatrix;
	NSButtonCell *_okButton;
	NSButtonCell *_cancelButton;
	NSButtonCell *_applyButton;
	NSMutableArray *_preferenceTitles;
	NSMutableArray *_preferenceModules;
	NSMutableDictionary *_masterPreferenceViews;
	NSMutableDictionary *_currentSessionPreferenceViews;
	NSBox *_originalContentView;
	BOOL _isModal;
	float _constrainedWidth;
	id _currentModule;
	void *_reserved;
}

+ (NSPreferences *) sharedPreferences;
+ (void) setDefaultPreferencesClass:(Class)fp12;
+ (Class) defaultPreferencesClass;
- (id) init;
- (void) dealloc;
- (void) addPreferenceNamed:fp12 owner:fp16;
- (void) _setupToolbar;
- (void) _setupUI;
- (NSSize) preferencesContentSize;
- (void) showPreferencesPanel;
- (void) showPreferencesPanelForOwner:fp12;
- (int) showModalPreferencesPanelForOwner:fp12;
- (int) showModalPreferencesPanel;
- (void) ok:fp12;
- (void) cancel:fp12;
- (void) apply:fp12;
- (void) _selectModuleOwner:fp12;
- (id) windowTitle;
- (void) confirmCloseSheetIsDone:fp12 returnCode:(int)fp16 contextInfo:(void *)fp20;
- (char) windowShouldClose:fp12;
- (void) windowDidResize:fp12;
- (NSSize) windowWillResize:fp16 toSize:(NSSize)fp20;
- (BOOL) usesButtons;
- (void) toolbarItemClicked:fp12;
- (id) toolbar:fp12 itemForItemIdentifier:fp16 willBeInsertedIntoToolbar:(char)fp20;
- (id) toolbarDefaultItemIdentifiers:fp12;
- (id) toolbarAllowedItemIdentifiers:fp12;
@end
