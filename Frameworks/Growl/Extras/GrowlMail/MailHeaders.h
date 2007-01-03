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

@class MailboxUid, MFError, MessageBody, Message, MessageStore;

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
+ (void)setMailAccounts:(NSArray *)fp8;
+ (void)_removeAccountFromSortedPaths:(id)fp8;
+ (NSArray *)activeAccounts;
+ (void)saveAccountInfoToDefaults;
+ (id)allEmailAddressesIncludingFullUserName:(BOOL)fp8;
+ (MailAccount *)_accountContainingEmailAddress:(id)fp8 matchingAddress:(id *)fp12 fullUserName:(id *)fp16;
+ (MailAccount *)accountContainingEmailAddress:(id)fp8;
+ (MailAccount *)accountThatMessageIsFrom:(Message *)fp8;
+ (MailAccount *)accountThatReceivedMessage:(Message *)fp8 matchingEmailAddress:(id *)fp12 fullUserName:(id *)fp16;
+ (id)outboxMessageStore:(BOOL)fp8;
+ (NSArray *)specialMailboxUids;
+ (NSArray *)_specialMailboxUidsUsingSelector:(SEL)fp8;
+ (NSArray *)inboxMailboxUids;
+ (NSArray *)trashMailboxUids;
+ (NSArray *)outboxMailboxUids;
+ (NSArray *)sentMessagesMailboxUids;
+ (NSArray *)draftMailboxUids;
+ (NSArray *)junkMailboxUids;
+ (NSArray *)allMailboxUids;
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
+ (MailboxUid *)mailboxUidForFileSystemPath:(id)fp8 create:(BOOL)fp12;
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
- (MailboxUid *)primaryMailboxUid;
- (MailboxUid *)rootMailboxUid;
- (MailboxUid *)draftsMailboxUidCreateIfNeeded:(BOOL)fp8;
- (MailboxUid *)junkMailboxUidCreateIfNeeded:(BOOL)fp8;
- (MailboxUid *)sentMessagesMailboxUidCreateIfNeeded:(BOOL)fp8;
- (MailboxUid *)trashMailboxUidCreateIfNeeded:(BOOL)fp8;
- (NSArray *)allMailboxUids;
- (void)setDraftsMailboxUid:(MailboxUid *)fp8;
- (void)setTrashMailboxUid:(MailboxUid *)fp8;
- (void)setJunkMailboxUid:(MailboxUid *)fp8;
- (void)setSentMessagesMailboxUid:(MailboxUid *)fp8;
- (void)deleteMessagesFromMailboxUid:(MailboxUid *)fp8 olderThanNumberOfDays:(unsigned int)fp12 compact:(BOOL)fp16;
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
- (NSString *)displayName;
- (NSString *)displayNameForMailboxUid:(MailboxUid *)fp8;
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
- (void)postUserInfoHasChangedForMailboxUid:(MailboxUid *)fp8 userInfo:(id)fp12;
- (void)setConnectionError:(id)fp8;
- (id)connectionError;
- (id)storeForMailboxUid:(MailboxUid *)fp8;
- (Class)storeClass;
- (void)setUnreadCount:(unsigned int)fp8 forMailbox:(id)fp12;
- (BOOL)hasUnreadMail;
- (id)mailboxUidForRelativePath:(id)fp8 create:(BOOL)fp12;
- (id)valueInMailboxesWithName:(id)fp8;
- (id)objectSpecifierForMessageStore:(id)fp8;
- (id)objectSpecifierForMailboxUid:(MailboxUid *)fp8;
- (id)objectSpecifier;

@end

@interface LocalAccount : MailAccount
{
	NSMutableArray *_disembodiedUids;
}

+ (id)localAccount;
+ (id)accountTypeString;
- (id)initWithPath:(id)fp8;
- (MailboxUid *)rootMailboxUid;
- (Class)storeClass;
- (id)mailboxPathExtension;
- (MailboxUid *)primaryMailboxUid;
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
- (MailboxUid *)mailboxUidForFileSystemPath:(NSString *)fp8;

@end

@interface MailboxUid : NSObject
{
    NSString *uniqueId;
    id _accountOrPathComponent;
    unsigned int _attributes;
    void *_tree;
    NSString *pendingNameChange;
    BOOL isSmartMailbox;
    NSMutableArray *criteria;
    BOOL allCriteriaMustBeSatisfied;
    NSString *_realFullPath;
    unsigned int _numberOfGenericChildren;
    BOOL failedToOpen;
    NSString *openFailureMessage;
}

+ (NSArray *)smartMailboxUids;
+ (void)setSmartMailboxUids:(NSArray *)fp8;
+ (id)_smartMailboxWithIdentifier:(id)fp8 inArray:(id)fp12;
+ (id)smartMailboxWithIdentifier:(id)fp8;
+ (id)smartMailboxesEnumerator;
+ (NSArray *)specialMailboxUids;
+ (void)setShouldIndexTrash:(BOOL)fp8;
+ (void)reimportJunk;
+ (void)setShouldIndexJunk:(BOOL)fp8;
- (BOOL)isSmartMailbox;
- (void)setIsSmartMailbox:(BOOL)fp8;
- (BOOL)isFlaggedSmartMailbox;
- (void)dealloc;
- (void)finalize;
- (id)init;
- (id)initWithAccount:(id)fp8;
- (id)initWithName:(id)fp8 attributes:(unsigned int)fp12 forAccount:(id)fp16;
- (id)initWithMailboxUid:(id)fp8;
- (id)initWithDictionaryRepresentation:(id)fp8;
- (id)dictionaryRepresentation;
- (id)uniqueId;
- (NSString *)displayName;
- (void)setPendingNameChange:(id)fp8;
- (NSString *)name;
- (void)setName:(NSString *)fp8;
- (unsigned int)attributes;
- (void)setAttributes:(unsigned int)fp8;
- (unsigned int)unreadCount;
- (void)setUnreadCount:(unsigned int)fp8;
- (BOOL)hasChildren;
- (void)invalidateCachedNumberOfGenericChildren;
- (unsigned int)numberOfGenericChildren;
- (unsigned int)numberOfChildren;
- (id)childAtIndex:(unsigned int)fp8;
- (unsigned int)indexOfChild:(id)fp8;
- (id)childWithName:(id)fp8;
- (id)mutableCopyOfChildren;
- (void)_deleteChildrenWithURLsIfInvalid:(id)fp8 fullPaths:(id)fp12;
- (BOOL)setChildren:(id)fp8;
- (void)sortChildren;
- (id)parent;
- (void)setParent:(id)fp8;
- (void)flushCriteria;
- (id)deepCopy;
- (void)setRepresentedAccount:(id)fp8;
- (id)representedAccount;
- (id)account;
- (id)applescriptAccount;
- (BOOL)isValid;
- (void)invalidate;
- (BOOL)isContainer;
- (BOOL)isStore;
- (BOOL)isSpecialMailboxUid;
- (NSString *)accountRelativePath;
- (NSString *)fullPathNonNil;
- (NSString *)fullPath;
- (NSString *)realFullPath;
- (NSString *)tildeAbbreviatedPath;
- (NSString *)pathRelativeToMailbox:(id)fp8;
- (NSURL *)URL;
- (NSString *)URLStringWithAccount:(id)fp8;
- (NSString *)oldURLString;
- (NSString *)URLString;
- (int)compareWithMailboxUid:(MailboxUid *)fp8;
- (int)indexToInsertChildMailboxUid:(MailboxUid *)fp8;
- (BOOL)isDescendantOfMailbox:(MailboxUid *)fp8;
- (id)depthFirstEnumerator;
- (id)description;
- (int)type;
- (void)setType:(int)fp8;
- (BOOL)isIndexable;
- (void)writeIndexFlagFileIfNeeded;
- (void)removeIndexFlagFileIfNeeded;
- (id)_loadUserInfo;
- (id)userInfoObjectForKey:(id)fp8;
- (void)setUserInfoObject:(id)fp8 forKey:(id)fp12;
- (BOOL)userInfoBoolForKey:(id)fp8;
- (void)setUserInfoBool:(BOOL)fp8 forKey:(id)fp12;
- (void)saveUserInfo;
- (id)userInfoDictionary;
- (void)setUserInfoWithDictionary:(id)fp8;
- (NSDictionary *)userInfo;
- (id)ancestralAccount;
- (id)criteria;
- (id)criterion;
- (void)setCriteria:(id)fp8;
- (id)abGroupsUsedInCriteria;
- (BOOL)criteriaAreValid:(id *)fp8;
- (BOOL)allCriteriaMustBeSatisfied;
- (void)setAllCriteriaMustBeSatisfied:(BOOL)fp8;
- (void)addressBookDidChange:(id)fp8;
- (id)store;
- (BOOL)failedToOpen;
- (id)openFailureMessage;
- (void)setFailedToOpen:(BOOL)fp8 message:(id)fp12;
- (id)copyWithZone:(id)fp8;

@end

typedef struct {
    unsigned int _field1;
    unsigned int _field2;
    char _field3;
    char _field4;
} CDAnonymousStruct6;

@interface Library : NSObject
{
}

+ (void)commitMessage:(Message *)fp8;
+ (void)flagsChangedForMessages:(NSArray *)fp8 flags:(id)fp12 oldFlagsByMessage:(id)fp16;
+ (void)coalesceMessageFileUpdate;
+ (void)coalesceCommitTransaction;
+ (void)cancelCoalescedTransaction;
+ (void)synchronouslyCommitTransaction;
+ (void)commitTransaction;
+ (void)commit;
+ (void)setFlagsFromDictionary:(id)fp8 forMessages:(NSArray *)fp12;
+ (void)setFlagsFromDictionary:(id)fp8 forMessages:(NSArray *)fp12 pushChanges:(BOOL)fp16;
+ (void)setFlags:(unsigned long)fp8 forMessage:(Message *)fp12;
+ (void)setFlagsForMessages:(NSArray *)fp8 mask:(unsigned long)fp12;
+ (void)setFlagsForMessages:(NSArray *)fp8;
+ (void)setBackgroundColorForMessages:(id)fp8 textColorForMessages:(id)fp12;
+ (void)setFlagsAndColorForMessages:(NSArray *)fp8;
+ (void)updateEncodingForMessage:(Message *)fp8;
+ (BOOL)initializeDatabase:(struct sqlite3 *)fp8;
+ (void)initialize;
+ (BOOL)setupLibrary;
+ (void)mailboxWillBeInvalidated:(id)fp8;
+ (id)plistDataForMessage:(id)fp8 subject:(id)fp12 sender:(id)fp16 to:(id)fp20 dateSent:(id)fp24 remoteID:(id)fp28 originalMailbox:(id)fp32 flags:(unsigned long long)fp36 mergeWithDictionary:(id)fp44;
+ (id)duplicateMessages:(id)fp8 newRemoteIDs:(id)fp12 forMailbox:(id)fp16 setFlags:(unsigned long long)fp20 clearFlags:(unsigned long long)fp28 createNewCacheFiles:(BOOL)fp36;
+ (BOOL)_writeEmlxFile:(id)fp8 forMessage:(id)fp12 withBodyData:(id)fp16 plistData:(id)fp20;
+ (void)touchDirectoryForMailbox:(id)fp8;
+ (id)addMessages:(NSArray *)messages withMailbox:(NSString *)mailbox fetchBodies:(BOOL)fetchBodies isInitialImport:(BOOL)isInitialImport oldMessagesByNewMessage:(id)oldMessagesByNewMessage;
+ (id)addMessages:(NSArray *)messages;
+ (id)addMessages:(NSArray *)messages withMailbox:(NSString *)mailbox;
+ (id)addMessages:(NSArray *)messages withMailbox:(NSString *)mailbox fetchBodies:(BOOL)fp16 oldMessagesByNewMessage:(id)fp20;
+ (void)setAttachmentNames:(id)fp8 forMessage:(id)fp12;
+ (void)setThreadPriority:(int)fp8;
+ (int)threadPriority;
+ (unsigned int)updateSequenceNumber;
+ (unsigned int)accessSequenceNumber;
+ (void)_rebuildActiveAccountsClause;
+ (void)sendMessagesMatchingQuery:(const char *)fp8 to:(id)fp12 options:(unsigned int)fp16;
+ (NSArray *)messagesMatchingQuery:(const char *)fp8 options:(unsigned int)fp12;
+ (NSArray *)messagesWhere:(id)fp8 sortedBy:(id)fp12 options:(unsigned int)fp16;
+ (void)sendMessagesForMailbox:(id)fp8 where:(id)fp12 sortedBy:(id)fp16 ascending:(BOOL)fp20 to:(id)fp24 options:(unsigned int)fp28;
+ (id)messagesForMailbox:(id)fp8 where:(id)fp12 sortedBy:(id)fp16 ascending:(BOOL)fp20 options:(unsigned int)fp24;
+ (id)messagesForMailbox:(id)fp8 olderThanNumberOfDays:(int)fp12;
+ (id)unreadMessagesForMailbox:(id)fp8;
+ (void)gatherCountsForMailbox:(id)fp8 totalCount:(unsigned long *)fp12 unreadCount:(unsigned long *)fp16 deletedCount:(unsigned long *)fp20 totalSize:(unsigned long long *)fp24;
+ (unsigned int)unreadCountForMailbox:(id)fp8;
+ (unsigned int)deletedCountForMailbox:(id)fp8;
+ (unsigned int)totalCountForMailbox:(id)fp8;
+ (Message *)messageWithRemoteID:(id)fp8 inRemoteMailbox:(id)fp12;
+ (unsigned int)maximumRemoteIDForMailbox:(id)fp8;
+ (id)getDetailsForMessagesWithRemoteIDInRange:(struct _NSRange)fp8 fromMailbox:(id)fp16;
+ (Message *)messageWithMessageID:(id)fp8;
+ (NSArray *)messagesWithMessageIDHeader:(id)fp8;
+ (Message *)messageWithLibraryID:(unsigned int)fp8 options:(unsigned int)fp12;
+ (Message *)messageWithLibraryID:(unsigned int)fp8;
+ (NSArray *)messagesInSameThreadAsMessages:(id)fp8 seenMessageIDs:(id)fp12 options:(unsigned int)fp16 db:(struct sqlite3 *)fp20;
+ (NSArray *)messagesInSameThreadAsMessages:(id)fp8 options:(unsigned int)fp12;
+ (id)firstReplyToMessage:(id)fp8;
+ (BOOL)messageHasRelatedNonJunkMessages:(id)fp8;
+ (id)stringForQuery:(id)fp8 monitor:(id)fp12;
+ (id)stringForQuery:(id)fp8;
+ (char *)bytesForQuery:(id)fp8;
+ (void)performQuery:(id)fp8;
+ (id)referencesForLibraryID:(unsigned int)fp8;
+ (id)urlForMailboxID:(unsigned int)fp8;
+ (id)mailboxUidForMessage:(Message *)fp8 lock:(BOOL)fp12;
+ (id)mailboxUidForMessage:(Message *)fp8;
+ (id)remoteStoreForMessage:(Message *)fp8;
+ (id)accountForMessage:(Message *)fp8;
+ (id)mailboxNameForMessage:(Message *)fp8;
+ (BOOL)loadSecondaryMetadataForMessage:(Message *)fp8;
+ (void)reloadMessage:(Message *)fp8;
+ (void)updateFileForMessage:(Message *)fp8;
+ (BOOL)shouldCancel;
+ (void)updateMessageFiles;
+ (void)messagesWereCompacted:(id)fp8 mailboxes:(id)fp12;
+ (void)compactMessages:(id)fp8;
+ (void)compactMailbox:(id)fp8;
+ (MailboxUid *)mailboxUidForURL:(NSString *)mailboxURL;
+ (BOOL)renameMailboxes:(id)fp8 to:(id)fp12;
+ (void)deleteMailboxes:(id)fp8;
+ (Message *)lastMessageWithMessageID:(id)fp8 inMailbox:(id)fp12;
+ (id)dataPathForMessage:(id)fp8 type:(int)fp12;
+ (id)dataPathForMessage:(id)fp8;
+ (id)realDataPathForMessage:(id)fp8;
+ (Message *)messageWithDataPath:(id)fp8;
+ (id)dataConsumerForMessage:(id)fp8 part:(id)fp12;
+ (id)dataConsumerForMessage:(id)fp8 isPartial:(BOOL)fp12;
+ (id)dataConsumerForMessage:(id)fp8;
+ (void)setData:(id)fp8 forMessage:(id)fp12 isPartial:(BOOL)fp16;
+ (id)bodyDataAtPath:(id)fp8 headerData:(id *)fp12;
+ (id)bodyDataForMessage:(id)fp8 andHeaderDataIfReadilyAvailable:(id *)fp12;
+ (id)bodyDataForMessage:(id)fp8;
+ (id)fullBodyDataForMessage:(id)fp8 andHeaderDataIfReadilyAvailable:(id *)fp12;
+ (id)fullBodyDataForMessage:(id)fp8;
+ (id)dataForMimePart:(id)fp8;
+ (BOOL)isMessageContentsLocallyAvailable:(id)fp8;
+ (BOOL)hasCacheFileForMessage:(id)fp8 directoryContents:(id)fp12;
+ (BOOL)hasCacheFileForMessage:(id)fp8 part:(id)fp12 directoryContents:(id)fp16;
+ (void)_markMessageAsViewed:(id)fp8 viewedDate:(id)fp12;
+ (void)markMessageAsViewed:(id)fp8;
+ (id)fixCriterionOnce:(id)fp8 expandedSmartMailboxes:(id)fp12;
+ (id)fixCriterionOnce:(id)fp8;
+ (id)fixCriterion:(id)fp8 expandedSmartMailboxes:(id)fp12;
+ (id)fixCriterion:(id)fp8;
+ (id)emailAddressesForGroupCriterion:(id)fp8;
+ (id)compoundCriterionToReplaceGroupCriterion:(id)fp8;
+ (id)compoundCriterionToReplaceCriterionOfType:(id)fp8 specialMailboxType:(int)fp12 forAccountURL:(id)fp16;
+ (id)expressionForCriterion:(id)fp8 context:(CDAnonymousStruct6 *)fp12 depth:(unsigned int)fp16 enclosingSmartMailboxes:(id)fp20;
+ (id)expressionForCriterion:(id)fp8 tables:(unsigned int *)fp12 baseTable:(unsigned int)fp16;
+ (id)queryForCriterion:(id)fp8 options:(unsigned int)fp12 baseTable:(unsigned int)fp16 isSubquery:(BOOL)fp20;
+ (id)queryForCriterion:(id)fp8 options:(unsigned int)fp12 baseTable:(unsigned int)fp16;
+ (id)queryForCriterion:(id)fp8 options:(unsigned int)fp12;
+ (void)shouldCancelMDQuery:(struct __MDQuery *)fp8;
+ (void)sendMessagesMatchingCriterion:(id)fp8 to:(id)fp12 options:(unsigned int)fp16;
+ (id)messagesMatchingCriterion:(id)fp8 options:(unsigned int)fp12;
+ (unsigned int)countForCriterion:(id)fp8 monitor:(id)fp12;
+ (unsigned int)countForCriterion:(id)fp8;
+ (id)filterContiguousMessages:(id)fp8 forCriterion:(id)fp12 options:(unsigned int)fp16;
+ (BOOL)rebuildMailbox:(id)fp8;
+ (BOOL)importMailbox:(id)fp8;
+ (BOOL)importing;
+ (BOOL)importEverythingIncludingDisabledAccounts:(BOOL)fp8;
+ (void)_upgradeMessageDirectoriesSynchronously;
+ (void)upgradeMessageDirectoriesIfNeeded;
+ (void)takeAccountsOnlineAllAccounts:(BOOL)fp8;
+ (BOOL)libraryExists;
+ (int)libraryStatus;
+ (BOOL)importableDataExists;
+ (id)currentMailbox;
+ (unsigned int)indexOfCurrentMailbox;
+ (unsigned int)totalNumberOfMailboxes;
+ (unsigned int)indexOfCurrentMessage;
+ (unsigned int)runningIndexOfCurrentMessage;
+ (unsigned int)messagesInMailbox;
+ (unsigned int)totalNumberOfMessages;
+ (BOOL)isBusy;
+ (void)cleanOldDatabases;

@end

typedef struct {
	unsigned int colorHasBeenEvaluated:1;
	unsigned int colorWasSetManually:1;
	unsigned int redColor:8;
	unsigned int greenColor:8;
	unsigned int blueColor:8;
	unsigned int loadingBody:1;
	unsigned int unused:5;
} CDAnonymousStruct3;

@interface Message : NSObject
{
	MessageStore *_store;
	unsigned int _messageFlags;
	CDAnonymousStruct3 _flags;
	unsigned int _preferredEncoding;
	NSString *_senderAddressComment;
	unsigned int _dateSentInterval;
	unsigned int _dateReceivedInterval;
	unsigned int _dateLastViewedInterval;
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
+ (id)forwardedMessagePrefixWithSpacer:(BOOL)fp8;
+ (id)replyPrefixWithSpacer:(BOOL)fp8;
+ (unsigned int)validatePriority:(int)fp8;
+ (unsigned int)displayablePriorityForPriority:(int)fp8;
+ (id)messageWithPersistentID:(id)fp8;
- (id)init;
- (id)copyWithZone:(NSZone *)fp8;
- (MessageStore *)messageStore;
- (void)setMessageStore:(MessageStore *)fp8;
- (MailboxUid *)mailbox;
- (id)headers;
- (id)headersIfAvailable;
- (unsigned long)messageFlags;
- (void)setMessageFlags:(unsigned long)fp8;
- (MessageBody *)messageBody;
- (MessageBody *)messageBodyIfAvailable;
- (MessageBody *)messageBodyUpdatingFlags:(BOOL)fp8;
- (MessageBody *)messageBodyIfAvailableUpdatingFlags:(BOOL)fp8;
- (id)messageDataIncludingFromSpace:(BOOL)fp8;
- (BOOL)colorHasBeenEvaluated;
- (id)color;
- (void)setColor:(id)fp8;
- (void)setColorHasBeenEvaluated:(BOOL)fp8;
- (void)setColor:(id)fp8 hasBeenEvaluated:(BOOL)fp12 flags:(unsigned long)fp16;
- (void)dealloc;
- (void)finalize;
- (unsigned int)messageSize;
- (NSAttributedString *)attributedString;
- (id)preferredEmailAddressToReplyWith;
- (NSString *)messageID;
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
- (id)headersForIndexingIncludingFullNamesAndDomains:(BOOL)fp8;
- (id)headersForIndexing;
- (id)headersForJunk;
- (id)stringForIndexingGettingHeadersIfAvailable:(id *)fp8 forJunk:(BOOL)fp12 updateBodyFlags:(BOOL)fp16;
- (id)stringForIndexingGettingHeadersIfAvailable:(id *)fp8 forJunk:(BOOL)fp12;
- (id)stringForIndexingGettingHeadersIfAvailable:(id *)fp8;
- (id)stringForIndexing;
- (id)stringForIndexingUpdatingBodyFlags:(BOOL)fp8;
- (id)stringForJunk;
- (unsigned int)numberOfAttachments;
- (int)junkMailLevel;
- (void)setPriorityFromHeaders:(id)fp8;
- (int)priority;
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
- (NSDate *)dateLastViewed;
- (NSTimeInterval)dateLastViewedAsTimeIntervalSince1970;
- (id)sender;
- (void)setSender:(id)fp8;
- (id)senderAddressComment;
- (id)to;
- (void)setTo:(id)fp8;
- (void)setMessageInfo:(id)fp8 to:(id)fp12 sender:(id)fp16 dateReceivedTimeIntervalSince1970:(double)fp20 dateSentTimeIntervalSince1970:(double)fp28 messageIDHeaderDigest:(id)fp36 inReplyToHeaderDigest:(id)fp40;
- (void)setMessageInfo:(id)fp8 to:(id)fp12 sender:(id)fp16 dateReceivedTimeIntervalSince1970:(double)fp20 dateSentTimeIntervalSince1970:(double)fp28 messageIDHeaderDigest:(id)fp36 inReplyToHeaderDigest:(id)fp40 dateLastViewedTimeIntervalSince1970:(double)fp44;
- (void)setMessageInfoFromMessage:(id)fp8;
- (id)references;
- (id)remoteID;
- (unsigned long)uid;
- (CDAnonymousStruct3)moreMessageFlags;
- (id)path;
- (id)account;
- (void)markAsViewed;
- (id)persistentID;
- (id)bodyData;
- (id)headerData;
- (id)dataForMimePart:(id)fp8;
- (id)matadorAttributes;

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

@interface POPMessage : Message
{
    int _messageNumber;
    NSString *_messageID;
    NSData *_messageData;
}

- (id)initWithPOP3FetchStore:(id)fp8;
- (void)dealloc;
- (void)finalize;
- (int)messageNumber;
- (void)setMessageNumber:(int)fp8;
- (id)messageData;
- (void)setMessageData:(id)fp8;
- (unsigned int)messageSize;
- (id)messageDataIncludingFromSpace:(BOOL)fp8;
- (NSString *)messageID;
- (void)setMessageID:(NSString *)fp8;
@end

typedef struct {
    unsigned int isRich:1;
    unsigned int isHTML:1;
    unsigned int hasTemporaryUid:1;
    unsigned int partsHaveBeenCached:1;
    unsigned int isPartial:1;
    unsigned int hasCustomEncoding:1;
    unsigned int reserved:26;
} CDAnonymousStruct4;

@interface IMAPMessage : Message <NSCoding>
{
    unsigned int _size;
    CDAnonymousStruct4 _imapFlags;
    unsigned int _uid;
}

+ (void)initialize;
- (id)initWithFlags:(unsigned long)fp8 size:(unsigned int)fp12 uid:(unsigned long)fp16;
- (id)initWithCoder:(id)fp8;
- (void)encodeWithCoder:(id)fp8;
- (NSString *)description;
- (unsigned int)messageSize;
- (id)messageID;
- (int)compareByNumberWithMessage:(Message *)fp8;
- (unsigned long)uid;
- (void)setUid:(unsigned long)fp8;
- (BOOL)isPartial;
- (void)setIsPartial:(BOOL)fp8;
- (BOOL)isMessageContentsLocallyAvailable;
- (BOOL)partsHaveBeenCached;
- (void)setPartsHaveBeenCached:(BOOL)fp8;
- (void)setPreferredEncoding:(unsigned long)fp8;
- (BOOL)hasTemporaryUid;
- (void)setHasTemporaryUid:(BOOL)fp8;
- (CDAnonymousStruct4)imapFlags;
- (id)mailboxName;
- (id)remoteID;

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

@protocol MVMailboxSelectionOwner
- (id)selectedMailboxes;
- (id)selectedMailbox;
- (void)selectPathsToMailboxes:(id)fp8;
- (BOOL)mailboxIsExpanded:(id)fp8;
- (void)revealMailbox:(id)fp8;
- (id)mailboxSelectionWindow;
@end

@interface MessageViewer : NSResponder <MVMailboxSelectionOwner>
{
	id _messageMall;
	id _tableManager;
	id _contentController;
	NSWindow *_window;
	id _splitView;
	id _verticalSplitView;
	id _viewerContainer;
	id _mailboxesView;
	id _outlineView;
	id _searchField;
	NSView *_searchFieldView;
	NSToolbarItem *_searchViewItem;
	NSString *_lastSearchPhrase;
	int _currentSearchType;
	int _currentSearchTarget;
	int _selectedTag;
	NSMenu *_tableHeaderMenu;
	id _outlineViewOwner;
	NSButton *newMailboxButton;
	NSPopUpButton *actionButton;
	id verticalSplitViewHandle;
	id mailboxPaneBottomView;
	BOOL _shouldPreventTableViewResize;
	BOOL _shouldMakeTableViewSelectionVisible;
	BOOL _shouldPreventFirstViewResize;
	BOOL _shouldMakeMessageSelectionVisible;
	BOOL _showingDefaultSearchString;
	BOOL _updatingSearchField;
	BOOL _allowShowingDeletedMessages;
	BOOL _suppressWindowTitleUpdates;
	float _restoreMailboxPaneToWidthAfterDragOperation;
	float _lastSplitViewPosition;
	float _lastMailboxSplitPosition;
	float _lastDragXPosition;
	NSArray *_mailboxesToDisplayWhenVisible;
	NSToolbar *_toolbar;
	NSMutableDictionary *_toolbarItems;
	NSDictionary *_savedDefaults;
	NSMutableArray *_transferOperations;
	NSMutableDictionary *_viewerContents;
	float _splitViewPositionBeforeSearch;
	id _animation;
	id _searchSliceView;
	BOOL _updatingToolbar;
	float _mailboxesViewWidthAtLastToolbarUpdate;
}

+ (id)allMessageViewers;
+ (id)allSingleMessageViewers;
+ (MessageViewer *)existingViewerForStore:(id)fp8;
+ (MessageViewer *)existingViewerForMailboxUid:(MailboxUid *)fp8;
+ (MessageViewer *)existingViewerForMessage:(Message *)fp8;
+ (MessageViewer *)newViewerForMailboxWithTag:(unsigned int)fp8;
+ (MessageViewer *)existingViewerShowingMessage:(Message *)fp8;
+ (void)registerNewViewer:(MessageViewer *)fp8;
+ (void)deregisterViewer:(MessageViewer *)fp8;
+ (void)showAllViewers;
+ (NSArray *)mailboxUidsBeingViewed;
+ (MessageViewer *)frontmostMessageViewer;
+ (void)searchForString:(id)fp8;
+ (NSArray *)_mailboxUidsForPaths:(id)fp8;
+ (void)saveDefaultsWithDelay;
+ (void)saveDefaults;
+ (void)restoreFromDefaults;
- (void)revealMessage:(id)fp8;
- (void)revealCurrentMessage;
- (void)_displayFollowup:(id)fp8;
- (void)_cantFindFollowupToMessage:(id)fp8;
- (void)showFollowupsToMessage:(id)fp8;
- (NSArray *)_mailboxUidsFromDefaults:(id)fp8;
- (id)initWithSavedDefaults:(id)fp8;
- (id)init;
- (id)plainInit;
- (id)initWithMailboxUids:(NSArray *)fp8;
- (void)dealloc;
- (void)_registerForApplicationNotifications;
- (void)_unregisterForApplicationNotifications;
- (void)_registerForStoreNotifications;
- (void)_unregisterForStoreNotifications;
- (void)storeBeingInvalidated:(id)fp8;
- (void)preferencesChanged:(id)fp8;
- (void)_setStore:(id)fp8;
- (BOOL)_isViewingMailboxUid:(MailboxUid *)fp8;
- (BOOL)_isViewingMessage:(Message *)fp8;
- (BOOL)_isShowingMessage:(Message *)fp8;
- (id)window;
- (void)show;
- (void)showAndMakeKey:(BOOL)fp8;
- (void)awakeFromNib;
- (void)_setupUI;
- (void)_setUpWindowContents;
- (void)_setupMailboxOutlineView;
- (void)_setupNextKeyViewLoop;
- (void)takeOverAsSelectionOwner;
- (void)resignAsSelectionOwner;
- (void)windowDidBecomeMain:(id)fp8;
- (void)nowWouldBeAGoodTimeToTerminate:(id)fp8;
- (BOOL)windowShouldClose:(id)fp8;
- (void)windowWillMiniaturize:(id)fp8;
- (NSSize)windowWillResize:(id)fp8 toSize:(NSSize)fp12;
- (void)openMailboxesPaneToWidth:(float)fp8;
- (BOOL)mailboxesPaneIsOpen;
- (BOOL)mailboxesPaneIsOpenWideEnoughToUse;
- (void)splitViewDidResizeSubviews:(id)fp8;
- (void)splitViewWillResizeSubviews:(id)fp8;
- (void)splitViewDoubleClickedOnDivider:(id)fp8;
- (void)toggleMailboxesPane:(id)fp8;
- (void)splitView:(id)fp8 resizeSubviewsWithOldSize:(NSSize)fp12;
- (BOOL)splitView:(id)fp8 canCollapseSubview:(id)fp12;
- (float)splitView:(id)fp8 constrainMinCoordinate:(float)fp12 ofSubviewAt:(int)fp16;
- (float)splitView:(id)fp8 constrainMaxCoordinate:(float)fp12 ofSubviewAt:(int)fp16;
- (float)maxMailboxesViewWidthAllowed;
- (float)idealMailboxesViewWidth;
- (void)updateMailboxButtonVisibilityForWidth:(float)fp8;
- (float)splitView:(id)fp8 constrainSplitPosition:(float)fp12 ofSubviewAt:(int)fp16;
- (id)selectedMailboxes;
- (id)selectedMailbox;
- (void)selectPathsToMailboxes:(id)fp8;
- (BOOL)mailboxIsExpanded:(id)fp8;
- (void)revealMailbox:(id)fp8;
- (id)mailboxSelectionWindow;
- (void)setSelectedMailboxes:(id)fp8;
- (id)selectedMessages;
- (void)setSelectedMessages:(id)fp8;
- (id)currentDisplayedMessage;
- (void)outlineViewDoubleClick:(id)fp8;
- (void)selectMailbox:(id)fp8;
- (void)keyDown:(id)fp8;
- (void)keyUp:(id)fp8;
- (void)_mailboxWasRenamed:(id)fp8;
- (void)mailboxSelectionChanged:(id)fp8;
- (void)_mallDidOpen;
- (void)_mallStructureDidChange;
- (void)smartMailboxCriteriaChanged:(id)fp8;
- (void)_setMailboxUids:(id)fp8;
- (BOOL)_selectionContainsMessagesWithDeletedStatusEqualTo:(BOOL)fp8;
- (BOOL)_selectionContainsMessagesWithReadStatusEqualTo:(BOOL)fp8;
- (BOOL)_selectionContainsMessagesWithFlaggedStatusEqualTo:(BOOL)fp8;
- (BOOL)_selectionContainsMessagesWithJunkMailLevelEqualTo:(int)fp8;
- (BOOL)_selectionContainsMessagesWithAttachments;
- (BOOL)atLeastOneSelectedMessageIsInOutbox:(id)fp8;
- (BOOL)_validateAction:(SEL)fp8 tag:(int)fp12;
- (BOOL)validateMenuItem:(id)fp8;
- (void)messageWasDisplayedInTextView:(id)fp8;
- (void)messageThreadSummaryWasDisplayedInTextView:(id)fp8;
- (void)checkNewMail:(id)fp8;
- (void)replyMessage:(id)fp8;
- (void)replyAllMessage:(id)fp8;
- (void)replyToSender:(id)fp8;
- (void)replyToOriginalSender:(id)fp8;
- (void)showComposeWindow:(id)fp8;
- (void)showAddressPanel:(id)fp8;
- (void)toggleAttachmentsArea:(id)fp8;
- (void)undeleteMessages:(id)fp8;
- (void)deleteMessages:(id)fp8;
- (void)deleteMessagesAllowingMoveToTrash:(BOOL)fp8;
- (void)selectAllMessages;
- (void)setFirstResponder;
- (void)replyViaIM:(id)fp8;
- (void)showAccountInfo:(id)fp8;
- (id)tableManager;
- (id)mailboxesOutlineViewOwner;
- (void)jumpToSelection:(id)fp8;
- (void)editorWithGatekeeperApproval:(id)fp8;
- (id)editorWithType:(int)fp8;
- (void)redirectMessage:(id)fp8;
- (void)forwardMessage:(id)fp8;
- (void)displaySelectedMessageInSeparateWindow:(id)fp8;
- (void)renameMailbox:(id)fp8;
- (void)moveMessagesToMailbox:(id)fp8;
- (void)copyMessagesToMailbox:(id)fp8;
- (id)_selectedMessagesWhoseFlag:(unsigned long)fp8 isEqualToState:(BOOL)fp12;
- (void)_changeFlag:(id)fp8 state:(BOOL)fp12 forMessages:(id)fp16 undoActionName:(id)fp20;
- (void)markAsRead:(id)fp8;
- (void)markAsUnread:(id)fp8;
- (void)markAsReadFromToolbar:(id)fp8;
- (void)markAsUnreadFromToolbar:(id)fp8;
- (void)markAsUnflagged:(id)fp8;
- (void)markAsFlagged:(id)fp8;
- (void)markAsFlaggedFromToolbar:(id)fp8;
- (void)markAsUnflaggedFromToolbar:(id)fp8;
- (void)changeColor:(id)fp8;
- (void)rebuildTableOfContents:(id)fp8;
- (void)_putMessageDataOntoPasteboard:(id)fp8 attributedString:(id)fp12 shouldDelete:(id)fp16 pasteboardType:(id)fp20;
- (void)_copyMessagesToPasteboard:(id)fp8 deleteWhenCopied:(BOOL)fp12 pasteboardType:(id)fp16;
- (void)_progressAlertDidEnd:(id)fp8 returnCode:(int)fp12 contextInfo:(void *)fp16;
- (BOOL)_doCopy:(id)fp8 deleteWhenCopied:(BOOL)fp12;
- (void)copy:(id)fp8;
- (void)cut:(id)fp8;
- (void)_pasteData:(id)fp8 pasteboardType:(id)fp12 destination:(id)fp16;
- (void)paste:(id)fp8;
- (void)startSpeaking:(id)fp8;
- (void)stopSpeaking:(id)fp8;
- (void)speechSynthesizer:(id)fp8 didFinishSpeaking:(BOOL)fp12;
- (void)showPrintPanel:(id)fp8;
- (BOOL)send:(id)fp8 forDraft:(BOOL)fp12;
- (BOOL)send:(id)fp8;
- (void)saveAs:(id)fp8;
- (void)saveAllAttachments:(id)fp8;
- (id)defaultSearchString;
- (void)showDefaultSearchString;
- (id)_criterionForMailbox:(id)fp8;
- (id)mailboxSearchCriterionForScope:(int)fp8;
- (void)searchIndex:(id)fp8;
- (BOOL)_isShowingSearchResults;
- (unsigned int)_searchResultCount;
- (BOOL)_canSaveSearchWithTarget:(int)fp8;
- (BOOL)_canSearchSelectedMailboxes;
- (BOOL)_canContentSearchSelectedMailboxes;
- (void)_showSearchSliceView;
- (void)_hideSearchSliceView;
- (void)_searchForString:(id)fp8;
- (void)_updateSearchStatus;
- (void)_clearSearch;
- (void)clearSearch:(id)fp8;
- (void)setupSearchParametersForTag:(int)fp8;
- (int)searchType;
- (int)searchTarget;
- (void)controlTextDidEndEditing:(id)fp8;
- (void)controlTextDidChange:(id)fp8;
- (void)_removeAttachmentsFromMessages:(id)fp8 fromStores:(id)fp12;
- (void)removeAttachments:(id)fp8;
- (void)sortByTagOfSender:(id)fp8;
- (void)focus:(id)fp8;
- (void)unfocus:(id)fp8;
- (void)openAllThreads:(id)fp8;
- (void)closeAllThreads:(id)fp8;
- (void)toggleThreadedMode:(id)fp8;
- (void)selectThread:(id)fp8;
- (void)selectPreviousInThread:(id)fp8;
- (void)selectNextInThread:(id)fp8;
- (void)showDeletions:(id)fp8;
- (void)hideDeletions:(id)fp8;
- (void)toggleContentsColumn:(id)fp8;
- (void)toggleMessageNumbersColumn:(id)fp8;
- (void)toggleMessageFlagsColumn:(id)fp8;
- (void)toggleFromColumn:(id)fp8;
- (void)togglePresenceColumn:(id)fp8;
- (void)toggleToColumn:(id)fp8;
- (void)toggleDateSentColumn:(id)fp8;
- (void)toggleDateReceivedColumn:(id)fp8;
- (void)toggleLocationColumn:(id)fp8;
- (void)toggleSizeColumn:(id)fp8;
- (void)writeDefaultsToArray:(id)fp8;
- (id)_saveDefaults;
- (void)_loadDefaults;
- (void)_setupFromDefaults;
- (id)_numberOfMessagesStringIsDrafts:(BOOL)fp8 omitUnread:(BOOL)fp12;
- (void)_updateWindowTitle;
- (void)_updateMessageMallUids:(id)fp8;
- (id)_currentMessageManager;
- (void)_setSplitViewPercentage:(float)fp8 animate:(BOOL)fp12;
- (void)animationDidEnd:(id)fp8;
- (void)messageWasSelected:(id)fp8 fromMessageBrowserController:(id)fp12;
- (void)scrollCurrentlySelectedMessageToTop;
- (void)messageWasDoubleClicked:(id)fp8;
- (void)messageBrowserView:(id)fp8 willStartDragWithEvent:(id)fp12;
- (void)draggedImage:(id)fp8 movedTo:(NSPoint)fp12;
- (void)messageBrowserViewDidEndDragging:(id)fp8;
- (BOOL)transferSelectedMessagesToMailbox:(id)fp8 deleteOriginals:(BOOL)fp12;
- (void)_reallyAnimateProgressInidicator;
- (void)_updateSearchStatusWithDelay;
- (void)threadDidExpand;
- (void)threadDidCollapse;
- (void)searchWillStart;
- (void)searchDidFinish;
- (void)searchDidUpdate;
- (NSArray *)selectedMailboxUids;
- (void)performSearch:(id)fp8;
- (void)saveSearch:(id)fp8;
- (void)reapplySortingRules:(id)fp8;
- (void)_returnToSenderSheetDidEnd:(id)fp8 returnCode:(int)fp12 contextInfo:(void *)fp16;
- (void)returnToSender:(id)fp8;
- (void)addSenderToAddressBook:(id)fp8;
- (void)markAsJunkMail:(id)fp8;
- (void)markMessagesAsJunkMail:(id)fp8 stores:(id)fp12;
- (void)_deleteJunkedMessages:(id)fp8 inStores:(id)fp12 moveToTrash:(BOOL)fp16;
- (void)synchronouslyMarkAsJunkMail:(id)fp8 inStores:(id)fp12 delete:(BOOL)fp16;
- (void)undoMarkMessagesAsJunkMail:(id)fp8 stores:(id)fp12;
- (void)markAsNotJunkMail:(id)fp8;
- (void)markMessagesAsNotJunkMail:(id)fp8 stores:(id)fp12;
- (void)synchronouslyMarkAsNotJunkMail:(id)fp8 inStores:(id)fp12;
- (BOOL)_transferSelectedMessagesToMailbox:(id)fp8 deleteOriginals:(BOOL)fp12;
- (void)_reportError:(id)fp8;
- (void)transfer:(id)fp8 didCompleteWithError:(id)fp12;
- (id)undoManagerForMessageTransfer:(id)fp8;
- (void)_updateSearchItemLabel;

@end

@protocol MVSelectionOwner
- (id)selection;
- (void)selectMessages:(NSArray *)fp8;
- (id)currentDisplayedMessage;
- (MessageStore *)messageStore;
- (BOOL)transferSelectionToMailbox:(id)fp8 deleteOriginals:(BOOL)fp12;
@end

@interface SingleMessageViewer : MessageViewer <MVSelectionOwner>
{
	NSView *_messageContentView;
	MessageStore *messageStore;
	id _spotlightBar;
}

+ (id)viewerForMessage:(id)fp8 showAllHeaders:(BOOL)fp12 viewingState:(id)fp16;
+ (void)restoreFromDefaults;
+ (void)saveDefaultsOmittingViewer:(id)fp8;
- (id)initForViewingMessage:(id)fp8 showAllHeaders:(BOOL)fp12 viewingState:(id)fp16 fromDefaults:(BOOL)fp20;
- (id)initForViewingMessage:(id)fp8 showAllHeaders:(BOOL)fp12 viewingState:(id)fp16;
- (id)initWithSavedDefaults:(id)fp8;
- (void)dealloc;
- (id)messageIDDictionary;
- (void)_adjustNewSingleViewerWindowFrame;
- (void)_setupFromDefaults;
- (void)showAndMakeKey:(BOOL)fp8;
- (void)_restoreViewer;
- (id)_saveDefaults;
- (void)takeOverAsSelectionOwner;
- (void)resignAsSelectionOwner;
- (id)selectedMessages;
- (void)messageFlagsDidChange:(id)fp8;
- (void)_setupToolBar;
- (BOOL)_isViewingMessage:(id)fp8;
- (BOOL)_selectionContainsMessagesWithReadStatusEqualTo:(BOOL)fp8;
- (BOOL)_selectionContainsMessagesWithFlaggedStatusEqualTo:(BOOL)fp8;
- (BOOL)_selectionContainsMessagesWithJunkMailLevelEqualTo:(int)fp8;
- (BOOL)_selectionContainsMessagesWithAttachments;
- (void)deleteMessages:(id)fp8;
- (void)deleteMessagesAllowingMoveToTrash:(BOOL)fp8;
- (void)replyMessage:(id)fp8;
- (void)replyAllMessage:(id)fp8;
- (void)replyToSender:(id)fp8;
- (void)replyToOriginalSender:(id)fp8;
- (void)forwardMessage:(id)fp8;
- (void)redirectMessage:(id)fp8;
- (BOOL)send:(id)fp8;
- (void)editorWithGatekeeperApproval:(id)fp8;
- (void)replaceWithEditorForType:(int)fp8;
- (void)_changeFlag:(id)fp8 state:(BOOL)fp12 forMessages:(id)fp16 undoActionName:(id)fp20;
- (void)keyDown:(id)fp8;
- (id)selection;
- (void)selectMessages:(NSArray *)messages;
- (Message *)currentDisplayedMessage;
- (MessageStore *)messageStore;
- (BOOL)transferSelectionToMailbox:(id)fp8 deleteOriginals:(BOOL)fp12;
- (void)_showSpotlightBarWithSearchString:(id)fp8;
- (void)_hideSpotlightBar;
- (void)setSearchString:(id)fp8;
- (void)revealMessage:(id)fp8;

@end

@interface MessageViewingState : NSObject
{
	NSAttributedString *_headerAttributedString;
	NSDictionary *_addressAttachments;
	NSDictionary *_plainAddresses;
	NSSet *_expandedAddressKeys;
	NSAttributedString *_attachmentsDescription;
	NSArray *_headerOrder;
	id mimeBody;
	id document;
	MFError *error;
	int headerIndent;
	int headerFontAdjustmentDebt;
	unsigned int preferredAlternative:23;
	unsigned int accountWasOffline:1;
	unsigned int dontCache:1;
	unsigned int showAllHeaders:1;
	unsigned int showDefaultHeaders:1;
	unsigned int isPrinting:1;
	unsigned int viewSource:1;
	unsigned int showControlChars:1;
	unsigned int showAttachments:1;
	unsigned int downloadRemoteURLs:1;
	unsigned int triedToDownloadRemoteURLs:1;
	unsigned int urlificationDone:1;
	unsigned int preferredEncoding;
	id monitor;
	NSString *sender;
	id displayer;
}

+ (void)initialize;
- (void)dealloc;
- (id)init;
- (id)mimeBody;
- (id)headerAttributedString;
- (void)setHeaderAttributedString:(id)fp8;
- (id)plainAddresses;
- (void)setPlainAddresses:(id)fp8;
- (id)addressAttachments;
- (void)setAddressAttachments:(id)fp8;
- (id)expandedAddressKeys;
- (void)setExpandedAddressKeys:(id)fp8;
- (id)attachmentsDescription;
- (void)setAttachmentsDescription:(id)fp8;
- (id)headerOrder;
- (void)setHeaderOrder:(id)fp8;

@end
