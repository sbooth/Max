@class WebBookmark, WebBookmarkGroup;

@protocol SynBookmark <NSObject>
- (id)title;
- (id)URLString;
- (id)UUID;
- (id)children;
@end

@interface WebBookmark : NSObject <NSCopying, SynBookmark> {
    WebBookmark *_parent;
    WebBookmarkGroup *_group;
    NSString *_identifier;
    NSString *_UUID;
    int _unreadRSSCount;
    int _RSSState;
}

+ (id)bookmarkOfType:(int)fp8;
+ (id)_bookmarkFromDictionaryRepresentation:(id)fp8 topLevelOnly:(BOOL)fp12 onlyAllowGenerationsLargerThan:(id)fp16 withGroup:(id)fp20;
+ (id)bookmarkFromDictionaryRepresentation:(id)fp8 onlyAllowGenerationsLargerThan:(id)fp12 withGroup:(id)fp16;
+ (id)bookmarkFromDictionaryRepresentation:(id)fp8 topLevelOnly:(BOOL)fp12 withGroup:(id)fp16;
- (void)dealloc;
- (id)copyWithZone:(struct _NSZone *)fp8;
- (id)title;
- (void)setTitle:(id)fp8;
- (id)icon;
- (int)bookmarkType;
- (id)description;
- (id)URLString;
- (void)setURLString:(id)fp8;
- (id)identifier;
- (void)setIdentifier:(id)fp8;
- (id)children;
- (id)rawChildren;
- (unsigned int)numberOfChildren;
- (unsigned int)_numberOfDescendants;
- (void)insertChild:(id)fp8 atIndex:(unsigned int)fp12;
- (void)removeChild:(id)fp8;
- (id)parent;
- (void)_setParent:(id)fp8;
- (void)_setUUID:(id)fp8;
- (id)UUID;
- (BOOL)_hasUUID;
- (id)group;
- (void)_setGroup:(id)fp8;
- (id)initWithIdentifier:(id)fp8 UUID:(id)fp12 group:(id)fp16;
- (id)init;
- (id)initFromDictionaryRepresentation:(id)fp8 topLevelOnly:(BOOL)fp12 withGroup:(id)fp16;
- (id)initFromDictionaryRepresentation:(id)fp8 withGroup:(id)fp12;
- (id)dictionaryRepresentation;
- (BOOL)contentMatches:(id)fp8;
- (BOOL)automaticallyOpensInTabs;
- (void)setAutomaticallyOpensInTabs:(BOOL)fp8;
- (void)setUnreadRSSCount:(int)fp8;
- (int)unreadRSSCount;
- (void)_resetUnreadRSSCount;
- (int)_RSSBookmarkState;
- (BOOL)_computeIsRSSBookmark;
- (void)_resetRSSBookmarkState;
- (BOOL)isRSSBookmark;
@end
