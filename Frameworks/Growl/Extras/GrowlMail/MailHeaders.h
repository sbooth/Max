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

@class MailboxUid, MFError;

@interface MVMailBundle : NSObject
{
}

+ (id)allBundles;
+ (id)composeAccessoryViewOwners;
+ (void)registerBundle;
+ (id)sharedInstance;
+ (BOOL)hasPreferencesPanel;
+ (id)preferencesOwnerClassName;
+ (id)preferencesPanelName;
+ (BOOL)hasComposeAccessoryViewOwner;
+ (id)composeAccessoryViewOwnerClassName;
- (void)dealloc;
- (void)_registerBundleForNotifications;

@end

@interface Account : NSObject
{
	NSMutableDictionary *_info;
	unsigned int _isOffline:1;
	unsigned int _willingToGoOnline:1;
	unsigned int _autosynchronizingEnabled:1;
	unsigned int _ignoreSSLCertificates:1;
	unsigned int _promptedToIgnoreSSLCertificates:1;
}

+ (void)initialize;
+ (BOOL)haveAccountsBeenConfigured;
+ (id)readAccountsUsingDefaultsKey:(id)fp8;
+ (void)saveAccounts:(id)fp8 usingDefaultsKey:(id)fp12;
+ (void)saveAccountInfoToDefaults;
+ (id)createAccountWithDictionary:(id)fp8;
+ (id)accountTypeString;
+ (BOOL)allObjectsInArrayAreOffline:(id)fp8;
- (id)init;
- (void)dealloc;
- (void)setAutosynchronizingEnabled:(BOOL)fp8;
- (void)_queueAccountInfoDidChange;
- (id)accountInfo;
- (void)_setAccountInfo:(id)fp8;
- (void)setAccountInfo:(id)fp8;
- (id)defaultsDictionary;
- (BOOL)isActive;
- (void)setIsActive:(BOOL)fp8;
- (BOOL)canGoOffline;
- (BOOL)isOffline;
- (void)setIsOffline:(BOOL)fp8;
- (BOOL)isWillingToGoOnline;
- (void)setIsWillingToGoOnline:(BOOL)fp8;
- (id)displayName;
- (void)setDisplayName:(id)fp8;
- (id)username;
- (void)setUsername:(id)fp8;
- (id)hostname;
- (void)setHostname:(id)fp8;
- (void)setPasswordInKeychain:(id)fp8;
- (void)_removePasswordInKeychain;
- (void)setTemporaryPassword:(id)fp8;
- (void)setPassword:(id)fp8;
- (id)passwordFromStoredUserInfo;
- (id)passwordFromKeychain;
- (id)password;
- (id)promptUserForPasswordWithMessage:(id)fp8;
- (id)promptUserIfNeededForPasswordWithMessage:(id)fp8;
- (unsigned int)portNumber;
- (unsigned int)defaultPortNumber;
- (unsigned int)defaultSecurePortNumber;
- (void)setPortNumber:(unsigned int)fp8;
- (id)serviceName;
- (id)secureServiceName;
- (void)releaseAllConnections;
- (void)validateConnections;
- (BOOL)usesSSL;
- (void)setUsesSSL:(BOOL)fp8;
- (id)sslProtocolVersion;
- (void)setSSLProtocolVersion:(id)fp8;
- (void)accountInfoDidChange;
- (id)securityProtocol;
- (void)setSecurityProcol:(id)fp8;
- (id)preferredAuthScheme;
- (void)setPreferredAuthScheme:(id)fp8;
- (id)saslProfileName;
- (Class)connectionClass;
- (BOOL)requiresAuthentication;
- (id)authenticatedConnection;
- (BOOL)_shouldTryDirectSSLConnectionOnPort:(unsigned int)fp8;
- (BOOL)_shouldRetryConnectionWithoutCertificateCheckingAfterError:(id)fp8;
- (BOOL)_connectAndAuthenticate:(id)fp8;
- (BOOL)_ignoreSSLCertificates;
- (void)_setIgnoreSSLCertificates:(BOOL)fp8;

@end

@interface MailAccount : Account
{
	NSString *_path;
	MailboxUid *_rootMailboxUid;
	struct {
		unsigned int cacheDirtyCount:16;
		unsigned int synchronizationThreadIsRunning:1;
		unsigned int backgroundFetchInProgress:1;
		unsigned int cacheHasBeenRead:1;
		unsigned int disableCacheWrite:1;
		unsigned int _UNUSED_:12;
	} _flags;
	MailboxUid *_inboxMailboxUid;
	MailboxUid *_draftsMailboxUid;
	MailboxUid *_sentMessagesMailboxUid;
	MailboxUid *_trashMailboxUid;
	MailboxUid *_junkMailboxUid;
	MFError *_lastConnectionError;
}

+ (void)initialize;
+ (BOOL)mailboxListingNotificationAreEnabled;
+ (void)disableMailboxListingNotifications;
+ (void)enableMailboxListingNotifications;
+ (BOOL)haveAccountsBeenConfigured;
+ (void)_addAccountToSortedPaths:(id)fp8;
+ (NSArray *)mailAccounts;
+ (void)setMailAccounts:(id)fp8;
+ (void)_removeAccountFromSortedPaths:(id)fp8;
+ (NSArray *)activeAccounts;
+ (void)saveAccountInfoToDefaults;
+ (id)allEmailAddressesIncludingFullUserName:(BOOL)fp8;
+ (id)_accountContainingEmailAddress:(id)fp8 matchingAddress:(id *)fp12 fullUserName:(id *)fp16;
+ (id)accountContainingEmailAddress:(id)fp8;
+ (id)accountThatMessageIsFrom:(id)fp8;
+ (id)accountThatReceivedMessage:(id)fp8 matchingEmailAddress:(id *)fp12 fullUserName:(id *)fp16;
+ (id)outboxMessageStore:(BOOL)fp8;
+ (id)specialMailboxUids;
+ (id)_specialMailboxUidsUsingSelector:(SEL)fp8;
+ (id)inboxMailboxUids;
+ (id)trashMailboxUids;
+ (id)outboxMailboxUids;
+ (id)sentMessagesMailboxUids;
+ (id)draftMailboxUids;
+ (id)junkMailboxUids;
+ (id)allMailboxUids;
+ (id)accountWithPath:(id)fp8;
+ (id)newAccountWithPath:(id)fp8;
+ (id)createAccountWithDictionary:(id)fp8;
+ (id)defaultPathForAccountWithHostname:(id)fp8 username:(id)fp12;
+ (id)defaultAccountDirectory;
+ (id)defaultPathNameForAccountWithHostname:(id)fp8 username:(id)fp12;
+ (id)defaultDeliveryAccount;
+ (BOOL)isAnyAccountOffline;
+ (BOOL)isAnyAccountOnline;
+ (void)_setOnlineStateOfAllAccountsTo:(BOOL)fp8;
+ (void)disconnectAllAccounts;
+ (void)connectAllAccounts;
+ (void)saveStateForAllAccounts;
+ (int)numberOfDaysToKeepLocalTrash;
+ (BOOL)allAccountsDeleteInPlace;
+ (void)synchronouslyEmptyMailboxUidType:(int)fp8 inAccounts:(id)fp12;
+ (void)resetAllSpecialMailboxes;
+ (id)mailboxUidForFileSystemPath:(id)fp8 create:(BOOL)fp12;
+ (void)deleteMailboxUidIfEmpty:(id)fp8;
- (void)synchronizeMailboxListAfterImport;
- (BOOL)isValidAccountWithError:(id)fp8 accountBeingEdited:(id)fp12 userCanOverride:(char *)fp16;
- (BOOL)cheapStoreAtPathIsEmpty:(id)fp8;
- (id)init;
- (id)initWithPath:(id)fp8;
- (void)dealloc;
- (id)path;
- (void)setPath:(id)fp8;
- (id)tildeAbbreviatedPath;
- (id)applescriptFullUserName;
- (void)setApplescriptFullUserName:(id)fp8;
- (id)fullUserName;
- (void)setFullUserName:(id)fp8;
- (id)deliveryAccount;
- (void)setDeliveryAccount:(id)fp8;
- (void)deliveryAccountWillBeRemoved:(id)fp8;
- (id)firstEmailAddress;
- (id)rawEmailAddresses;
- (id)emailAddresses;
- (id)applescriptEmailAddresses;
- (void)setApplescriptEmailAddresses:(id)fp8;
- (void)setEmailAddresses:(id)fp8;
- (BOOL)shouldAutoFetch;
- (void)setShouldAutoFetch:(BOOL)fp8;
- (BOOL)fileManager:(id)fp8 shouldProceedAfterError:(id)fp12;
- (void)_synchronouslyInvalidateAndDelete:(BOOL)fp8;
- (void)deleteAccount;
- (void)saveState;
- (void)releaseAllConnections;
- (void)setIsOffline:(BOOL)fp8;
- (void)setIsWillingToGoOnline:(BOOL)fp8;
- (BOOL)canFetch;
- (id)defaultsDictionary;
- (void)nowWouldBeAGoodTimeToStartBackgroundSynchronization;
- (BOOL)canAppendMessages;
- (BOOL)canBeSynchronized;
- (void)synchronizeAllMailboxes;
- (void)fetchAsynchronously;
- (void)fetchSynchronously;
- (BOOL)isFetching;
- (void)newMailHasBeenReceived;
- (id)primaryMailboxUid;
- (id)rootMailboxUid;
- (id)draftsMailboxUidCreateIfNeeded:(BOOL)fp8;
- (id)junkMailboxUidCreateIfNeeded:(BOOL)fp8;
- (id)sentMessagesMailboxUidCreateIfNeeded:(BOOL)fp8;
- (id)trashMailboxUidCreateIfNeeded:(BOOL)fp8;
- (id)allMailboxUids;
- (void)setDraftsMailboxUid:(id)fp8;
- (void)setTrashMailboxUid:(id)fp8;
- (void)setJunkMailboxUid:(id)fp8;
- (void)setSentMessagesMailboxUid:(id)fp8;
- (void)deleteMessagesFromMailboxUid:(id)fp8 olderThanNumberOfDays:(unsigned int)fp12 compact:(BOOL)fp16;
- (void)_setEmptyFrequency:(int)fp8 forKey:(id)fp12;
- (int)_emptyFrequencyForKey:(id)fp8 defaultValue:(id)fp12;
- (int)emptySentMessagesFrequency;
- (void)setEmptySentMessagesFrequency:(int)fp8;
- (int)emptyJunkFrequency;
- (void)setEmptyJunkFrequency:(int)fp8;
- (int)emptyTrashFrequency;
- (void)setEmptyTrashFrequency:(int)fp8;
- (BOOL)shouldMoveDeletedMessagesToTrash;
- (void)setShouldMoveDeletedMessagesToTrash:(BOOL)fp8;
- (void)emptySpecialMailboxesThatNeedToBeEmptiedAtQuit;
- (id)displayName;
- (id)displayNameForMailboxUid:(id)fp8;
- (BOOL)containsMailboxes;
- (void)resetSpecialMailboxes;
- (id)mailboxPathExtension;
- (BOOL)canCreateNewMailboxes;
- (BOOL)newMailboxNameIsAcceptable:(id)fp8 reasonForFailure:(id *)fp12;
- (BOOL)canMailboxBeRenamed:(id)fp8;
- (BOOL)canMailboxBeDeleted:(id)fp8;
- (id)createMailboxWithParent:(id)fp8 name:(id)fp12;
- (BOOL)renameMailbox:(id)fp8 newName:(id)fp12 parent:(id)fp16;
- (BOOL)deleteMailbox:(id)fp8;
- (void)accountInfoDidChange;
- (void)postUserInfoHasChangedForMailboxUid:(id)fp8 userInfo:(id)fp12;
- (void)setConnectionError:(id)fp8;
- (id)connectionError;
- (id)storeForMailboxUid:(id)fp8;
- (Class)storeClass;
- (void)setUnreadCount:(unsigned int)fp8 forMailbox:(id)fp12;
- (BOOL)hasUnreadMail;
- (id)mailboxUidForRelativePath:(id)fp8 create:(BOOL)fp12;
- (id)valueInMailboxesWithName:(id)fp8;
- (id)objectSpecifierForMessageStore:(id)fp8;
- (id)objectSpecifierForMailboxUid:(id)fp8;
- (id)objectSpecifier;

@end

@interface LocalAccount : MailAccount
{
	NSMutableArray *_disembodiedUids;
}

+ (id)localAccount;
+ (id)accountTypeString;
- (id)initWithPath:(id)fp8;
- (id)rootMailboxUid;
- (Class)storeClass;
- (id)mailboxPathExtension;
- (id)primaryMailboxUid;
- (void)setPath:(id)fp8;
- (id)displayName;
- (void)setHostname:(id)fp8;
- (void)setUsername:(id)fp8;
- (id)password:(BOOL)fp8;
- (void)setPassword:(id)fp8;
- (BOOL)canFetch;
- (BOOL)shouldAutoFetch;
- (BOOL)isOffline;
- (void)setIsOffline:(BOOL)fp8;
- (int)emptyTrashFrequency;
- (BOOL)shouldMoveDeletedMessagesToTrash;
- (void)_synchronouslyLoadListingForParent:(id)fp8;
- (id)_copyMailboxUidWithParent:(id)fp8 name:(id)fp12 attributes:(unsigned int)fp16 existingMailboxUid:(id)fp20;
- (id)createMailboxWithParent:(id)fp8 name:(id)fp12;
- (BOOL)renameMailbox:(id)fp8 newName:(id)fp12 parent:(id)fp16;
- (void)insertInMailboxes:(id)fp8 atIndex:(unsigned int)fp12;
- (id)mailboxUidForFileSystemPath:(id)fp8;

@end

@interface MessageStore : NSObject
{
	struct {
		unsigned int isReadOnly:1;
		unsigned int hasUnsavedChangesToMessageData:1;
		unsigned int hasUnsavedChangesToIndex:1;
		unsigned int indexIsValid:1;
		unsigned int haveOpenLockFile:1;
		unsigned int rebuildingTOC:1;
		unsigned int compacting:1;
		unsigned int cancelInvalidation:1;
		unsigned int forceInvalidation:1;
		unsigned int isWritingChangesToDisk:1;
		unsigned int isTryingToClose:1;
		unsigned int reserved:21;
	} _flags;
	MailboxUid *_mailboxUid;
	MailAccount *_account;
	id _index;
	NSMutableArray *_allMessages;
	NSMutableArray *_messagesToBeAddedToIndex;
	NSMutableArray *_messagesToBeRemovedFromIndex;
	unsigned int _allMessagesSize;
	unsigned int _deletedMessagesSize;
	unsigned int _deletedMessageCount;
	unsigned int _unreadMessageCount;
	id _updateIndexMonitor;
	int _state;
	id _headerDataCache;
	id _headerCache;
	id _bodyDataCache;
	id _bodyCache;
	NSTimer *_timer;
	NSMutableSet *_uniqueStrings;
	double timeOfLastAutosaveOperation;
}

+ (void)initialize;
+ (unsigned int)numberOfCurrentlyOpenStores;
+ (id)descriptionOfOpenStores;
+ (id)currentlyAvailableStoreForUid:(id)fp8;
+ (id)currentlyAvailableStoresForAccount:(id)fp8;
+ (id)registerAvailableStore:(id)fp8;
+ (void)removeStoreFromCache:(id)fp8;
+ (BOOL)createEmptyStoreIfNeededForPath:(id)fp8;
+ (BOOL)createEmptyStoreForPath:(id)fp8;
+ (BOOL)storeAtPathIsWritable:(id)fp8;
+ (BOOL)cheapStoreAtPathIsEmpty:(id)fp8;
+ (int)copyMessages:(id)fp8 toMailboxUid:(id)fp12 shouldDelete:(BOOL)fp16;
- (void)release;
- (id)initWithMailboxUid:(id)fp8 readOnly:(BOOL)fp12;
- (id)copyWithZone:(struct _NSZone *)fp8;
- (void)dealloc;
- (void)openAsynchronouslyUpdatingIndex:(BOOL)fp8 andOtherMetadata:(BOOL)fp12;
- (void)openAsynchronously;
- (void)openSynchronously;
- (void)openSynchronouslyUpdatingIndex:(BOOL)fp8 andOtherMetadata:(BOOL)fp12;
- (void)updateMetadataAsynchronously;
- (void)updateMetadata;
- (void)didOpen;
- (void)writeUpdatedMessageDataToDisk;
- (void)invalidateSavingChanges:(BOOL)fp8;
- (id)account;
- (id)mailboxUid;
- (BOOL)isOpened;
- (id)storePathRelativeToAccount;
- (id)displayName;
- (const char *)displayNameForLogging;
- (BOOL)isReadOnly;
- (id)description;
- (BOOL)isTrash;
- (BOOL)isDrafts;
- (void)messageFlagsDidChange:(id)fp8 flags:(id)fp12;
- (void)structureDidChange;
- (void)messagesWereAdded:(id)fp8;
- (void)messagesWereCompacted:(id)fp8;
- (void)updateUserInfoToLatestValues;
- (unsigned int)totalMessageSize;
- (void)deletedCount:(unsigned int *)fp8 andSize:(unsigned int *)fp12;
- (unsigned int)totalCount;
- (unsigned int)unreadCount;
- (unsigned int)indexOfMessage:(id)fp8;
- (id)copyOfAllMessages;
- (id)mutableCopyOfAllMessages;
- (void)addMessagesToAllMessages:(id)fp8;
- (void)addMessageToAllMessages:(id)fp8;
- (void)insertMessageToAllMessages:(id)fp8 atIndex:(unsigned int)fp12;
- (id)_defaultRouterDestination;
- (id)routeMessages:(id)fp8;
- (id)finishRoutingMessages: (NSArray *)messages routed: (NSArray *)routed;
- (BOOL)canRebuild;
- (void)rebuildTableOfContentsAsynchronously;
- (BOOL)canCompact;
- (void)doCompact;
- (void)deleteMessagesOlderThanNumberOfDays:(int)fp8 compact:(BOOL)fp12;
- (void)deleteMessages:(id)fp8 moveToTrash:(BOOL)fp12;
- (void)undeleteMessages:(id)fp8;
- (void)deleteLastMessageWithHeader:(id)fp8 forHeaderKey:(id)fp12 compactWhenDone:(BOOL)fp16;
- (BOOL)allowsAppend;
- (int)undoAppendOfMessageIDs:(id)fp8;
- (int)appendMessages:(id)fp8 unsuccessfulOnes:(id)fp12 newMessageIDs:(id)fp16;
- (int)appendMessages:(id)fp8 unsuccessfulOnes:(id)fp12;
- (id)messageWithValue:(id)fp8 forHeader:(id)fp12 options:(unsigned int)fp16;
- (id)messageForMessageID:(id)fp8;
- (void)_setHeaderDataInCache:(id)fp8 forMessage:(id)fp12;
- (id)headerDataForMessage:(id)fp8;
- (id)bodyDataForMessage:(id)fp8;
- (id)fullBodyDataForMessage:(id)fp8;
- (id)bodyForMessage:(id)fp8 fetchIfNotAvailable:(BOOL)fp12;
- (id)headersForMessage:(id)fp8;
- (id)dataForMimePart:(id)fp8;
- (BOOL)hasCachedDataForMimePart:(id)fp8;
- (id)uniquedString:(id)fp8;
- (id)colorForMessage:(id)fp8;
- (BOOL)_shouldChangeComponentMessageFlags;
- (id)setFlagsFromDictionary:(id)fp8 forMessages:(id)fp12;
- (id)setFlagsFromDictionary:(id)fp8 forMessage:(id)fp12;
- (void)setFlag:(id)fp8 state:(BOOL)fp12 forMessages:(id)fp16;
- (void)setColor:(id)fp8 highlightTextOnly:(BOOL)fp12 forMessages:(id)fp16;
- (void)messageColorsNeedToBeReevaluated;
- (void)startSynchronization;
- (id)performBruteForceSearchWithString:(id)fp8 options:(int)fp12;
- (char *)createSerialNumberStringFrom:(char *)fp8 colorCode:(unsigned short)fp12;
- (id)_getSerialNumberString;
- (void)setNumberOfAttachments:(unsigned int)fp8 isSigned:(BOOL)fp12 isEncrypted:(BOOL)fp16 forMessage:(id)fp20;
- (void)updateNumberOfAttachmentsForMessages:(id)fp8;
- (void)updateMessageColorsSynchronouslyForMessages:(id)fp8;
- (void)updateMessageColorsAsynchronouslyForMessages:(id)fp8;
- (void)setJunkMailLevel:(int)fp8 forMessages:(id)fp12;
- (void)setJunkMailLevel:(int)fp8 forMessages:(id)fp12 trainJunkMailDatabase:(BOOL)fp16;
- (id)status;
- (void)fetchSynchronously;
- (BOOL)setPreferredEncoding:(unsigned long)fp8 forMessage:(id)fp12;
- (void)suggestSortOrder:(id)fp8 ascending:(BOOL)fp12;
- (id)sortOrder;
- (BOOL)isSortedAscending;

@end

@interface Message : NSObject
{
	MessageStore *_store;
	unsigned int _messageFlags;
	struct {
		unsigned int colorHasBeenEvaluated:1;
		unsigned int colorWasSetManually:1;
		unsigned int redColor:8;
		unsigned int greenColor:8;
		unsigned int blueColor:8;
		unsigned int loadingBody:1;
		unsigned int unused:5;
	} _flags;
	unsigned int _preferredEncoding;
	NSString *_senderAddressComment;
	unsigned int _dateSentInterval;
	unsigned int _dateReceivedInterval;
	NSString *_subject;
	unsigned char _subjectPrefixLength;
	NSString *_to;
	NSString *_sender;
	NSData *_messageIDHeaderDigest;
	NSData *_inReplyToHeaderDigest;
}

+ (void)initialize;
+ (id)verboseVersion;
+ (id)frameworkVersion;
+ (void)setUserAgent:(id)fp8;
+ (id)userAgent;
+ (id)messageWithRFC822Data:(id)fp8;
+ (id)_filenameFromSubject:(id)fp8 inDirectory:(id)fp12 ofType:(id)fp16;
+ (id)makeUniqueAttachmentNamed:(id)fp8 inDirectory:(id)fp12;
+ (id)makeUniqueAttachmentNamed:(id)fp8 withExtension:(id)fp12 inDirectory:(id)fp16;
- (id)init;
- (id)copyWithZone:(struct _NSZone *)fp8;
- (MessageStore *)messageStore;
- (void)setMessageStore:(MessageStore *)fp8;
- (id)headers;
- (unsigned long)messageFlags;
- (void)setMessageFlags:(unsigned long)fp8;
- (id)messageBody;
- (id)messageBodyIfAvailable;
- (id)messageDataIncludingFromSpace:(BOOL)fp8;
- (BOOL)colorHasBeenEvaluated;
- (id)color;
- (void)setColor:(id)fp8;
- (void)setColorHasBeenEvaluated:(BOOL)fp8;
- (void)dealloc;
- (unsigned int)messageSize;
- (id)attributedString;
- (id)preferredEmailAddressToReplyWith;
- (id)messageID;
- (id)messageIDHeaderDigest;
- (void)unlockedSetMessageIDHeaderDigest:(id)fp8;
- (void)setMessageIDHeaderDigest:(id)fp8;
- (id)_messageIDHeaderDigestIvar;
- (BOOL)needsMessageIDHeader;
- (id)inReplyToHeaderDigest;
- (void)unlockedSetInReplyToHeaderDigest:(id)fp8;
- (void)setInReplyToHeaderDigest:(id)fp8;
- (id)_inReplyToHeaderDigestIvar;
- (int)compareByNumberWithMessage:(id)fp8;
- (BOOL)isMessageContentsLocallyAvailable;
- (id)headersForIndexingIncludingFullNames:(BOOL)fp8;
- (id)headersForIndexing;
- (id)headersForJunk;
- (id)stringForIndexingGettingHeadersIfAvailable:(id *)fp8 forJunk:(BOOL)fp12;
- (id)stringForIndexingGettingHeadersIfAvailable:(id *)fp8;
- (id)stringForIndexing;
- (id)stringForJunk;
- (unsigned int)numberOfAttachments;
- (int)junkMailLevel;
- (unsigned long)preferredEncoding;
- (void)setPreferredEncoding:(unsigned long)fp8;
- (id)rawSourceFromHeaders:(id)fp8 body:(id)fp12;
- (BOOL)_doesDateAppearToBeSane:(id)fp8;
- (id)_dateFromReceivedHeadersInHeaders:(id)fp8;
- (id)_dateFromDateHeaderInHeaders:(id)fp8;
- (void)_setDateReceivedFromHeaders:(id)fp8;
- (void)_setDateSentFromHeaders:(id)fp8;
- (void)loadCachedHeaderValuesFromHeaders:(id)fp8;
- (id)subjectAndPrefixLength:(unsigned int *)fp8;
- (id)subjectNotIncludingReAndFwdPrefix;
- (id)subject;
- (void)setSubject:(id)fp8;
- (id)dateReceived;
- (id)dateSent;
- (void)setDateReceivedTimeIntervalSince1970:(double)fp8;
- (double)dateReceivedAsTimeIntervalSince1970;
- (BOOL)needsDateReceived;
- (double)dateSentAsTimeIntervalSince1970;
- (void)setDateSentTimeIntervalSince1970:(double)fp8;
- (id)sender;
- (void)setSender:(id)fp8;
- (id)senderAddressComment;
- (id)to;
- (void)setTo:(id)fp8;
- (void)setMessageInfo:(id)fp8 to:(id)fp12 sender:(id)fp16 dateReceivedTimeIntervalSince1970:(double)fp20 dateSentTimeIntervalSince1970:(double)fp28 messageIDHeaderDigest:(id)fp36 inReplyToHeaderDigest:(id)fp40;
- (void)setMessageInfoFromMessage:(id)fp8;

@end

@interface MessageBody : NSObject
{
	Message *_message;
}

- (id)rawData;
- (id)attributedString;
- (BOOL)isHTML;
- (BOOL)isRich;
- (NSString *)stringForIndexing;
- (NSString *)stringValueForJunkEvaluation:(BOOL)fp8;
- (void)setMessage:(id)fp8;
- (id)message;
- (void)calculateNumberOfAttachmentsIfNeeded;
- (void)calculateNumberOfAttachmentsDecodeIfNeeded;
- (id)attachments;
- (id)textHtmlPart;
- (id)webArchive;

@end

@interface Message (ScriptingSupport)
- (id)objectSpecifier;
- (void)_setAppleScriptFlag:(id)fp8 state:(BOOL)fp12;
- (BOOL)isRead;
- (void)setIsRead:(BOOL)fp8;
- (BOOL)wasRepliedTo;
- (void)setWasRepliedTo:(BOOL)fp8;
- (BOOL)wasForwarded;
- (void)setWasForwarded:(BOOL)fp8;
- (BOOL)wasRedirected;
- (void)setWasRedirected:(BOOL)fp8;
- (BOOL)isJunk;
- (void)setIsJunk:(BOOL)fp8;
- (BOOL)isDeleted;
- (void)setIsDeleted:(BOOL)fp8;
- (BOOL)isFlagged;
- (void)setIsFlagged:(BOOL)fp8;
- (id)replyTo;
- (id)scriptedMessageSize;
- (id)content;
- (void)_addRecipientsForKey:(id)fp8 toArray:(id)fp12;
- (id)recipients;
- (id)toRecipients;
- (id)ccRecipients;
- (id)bccRecipients;
- (id)container;
- (void)setContainer:(id)fp8;
- (id)messageIDHeader;
- (id)rawSource;
- (id)allHeaders;
- (int)actionColorMessage;
- (void)setBackgroundColor:(int)fp8;
- (id)appleScriptHeaders;
@end

@interface TOCMessage : Message
{
	struct _NSRange _mboxRange;
	NSString *_attachments;
	NSString *_messageID;
}

+ (id)messageIDForSender:(id)fp8 subject:(id)fp12 dateAsTimeInterval:(double)fp16;
- (id)initWithMessage:(id)fp8;
- (void)dealloc;
- (unsigned int)loadCachedInfoFromBytes:(const char *)fp8 length:(unsigned int)fp12 isDirty:(char *)fp16 usingUniqueStrings:(id)fp20;
- (id)cachedData;
- (struct _NSRange)mboxRange;
- (void)setMboxRange:(struct _NSRange)fp8;
- (id)attachment;
- (id)messageID;
- (int)compareByNumberWithMessage:(id)fp8;
- (unsigned int)messageSize;
- (id)description;
@end

@interface NSString (NSEmailAddressString)
+ (id)nameExtensions;
+ (id)nameExtensionsThatDoNotNeedCommas;
+ (id)partialSurnames;
+ (id)formattedAddressWithName:(id)fp8 email:(id)fp12 useQuotes:(BOOL)fp16;
- (id)uncommentedAddress;
- (id)uncommentedAddressRespectingGroups;
- (NSString *)addressComment;
- (void)firstName:(id *)fp8 middleName:(id *)fp12 lastName:(id *)fp16 extension:(id *)fp20;
- (BOOL)appearsToBeAnInitial;
- (NSString *)fullName;
- (id)addressList;
- (id)trimCommasSpacesQuotes;
- (id)componentsSeparatedByCommaRespectingQuotesAndParens;
- (id)searchStringComponents;
- (BOOL)isLegalEmailAddress;
- (id)addressDomain;
@end

@interface MailAddressManager : NSObject
{
	id *_addressBook;
	id *_imageCache;
	NSMutableDictionary *emailsAwaitingImage;
	NSMutableDictionary *recordsCache;
	NSMutableSet *addressesWithNoRecords;
	BOOL needToTrimRecordCaches;
}

+ (id)addressManager;
- (id)init;
- (void)dealloc;
- (id)loadAddressBookAsynchronously;
- (void)loadAddressBookSynchronously;
- (void)_importDidBegin:(id)fp8;
- (void)_importDidUpdate:(id)fp8;
- (void)_importDidEnd:(id)fp8;
- (id)bestRecordMatchingFormattedAddress:(id)fp8;
- (void)trimRecordCachesAfterDelay;
- (void)trimRecordCaches;
- (void)addressBookDidChange:(id)fp8;
- (void)recordsMatchingDictionary:(id)fp8;
- (id)recordsMatchingSearchString:(id)fp8;
- (BOOL)addressBookPerson:(id)fp8 nameMatchesSearchWords:(id)fp12;
- (BOOL)email:(id)fp8 matchesSearchWords:(id)fp12;
- (id)betterRecordOfRecent:(id)fp8 addressBook:(id)fp12;
- (id)recordForUniqueId:(id)fp8;
- (id)groupsMatchingString:(id)fp8;
- (void)updateDatesForRecentRecord:(id)fp8;
- (void)_addAddresses:(id)fp8 asRecent:(BOOL)fp12;
- (void)addRecentAddresses:(id)fp8;
- (void)addAddresses:(id)fp8;
- (id)addRecentToAddressBook:(id)fp8;
- (id)addAddressToAddressBook:(id)fp8;
- (void)removeRecentAddresses:(id)fp8;
- (void)removeRecentRecord:(id)fp8;
- (id)addEmailAddressToCardMatchingFirstAndLastNameFromFormattedAddress:(id)fp8;
- (id)addressBookRecordForRecentRecord:(id)fp8 orEmail:(id)fp12;
- (id)addressBookPersonForEmail:(id)fp8;
- (id)addressBookRecordsForFirstName:(id)fp8 lastName:(id)fp12;
- (id)imageForMailAddress:(id)fp8;
- (void)fetchImageForAddress:(id)fp8;
- (void)consumeImageData:(id)fp8 forTag:(int)fp12;
- (void)cacheImage:(id)fp8 forAddress:(id)fp12;
- (id)groups;
- (void)_addEmailsFromGroup:(id)fp8 toDictionary:(id)fp12;
- (id)emailAddressesFromGroup:(id)fp8;
- (id)expandPrivateAliases:(id)fp8;

@end
