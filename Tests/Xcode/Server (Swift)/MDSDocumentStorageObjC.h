//
//  MDSDocumentStorageObjC.h
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/23/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociationGetIntegerValueAction

typedef NS_ENUM(NSInteger) {
	kMDSAssociationGetValueActionDetail,
	kMDSAssociationGetValueActionSum,
} MDSAssociationGetValueAction;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSAssociationItem

@interface MDSAssociationItem : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	fromDocumentID;
@property (nonatomic, strong)	NSString*	toDocumentID;

// MARK: Instance methods

- (instancetype) initWithFromDocumentID:(NSString*) fromDocumentID toDocumentID:(NSString*) toDocumentID;

@end

typedef	NSArray<MDSAssociationItem*>	MDSAssociationItemArray;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSAssociationUpdate

typedef NS_ENUM(NSInteger) {
	kMDSAssociationUpdateActionAdd,
	kMDSAssociationUpdateActionRemove,
} MDSAssociationUpdateAction;

@interface MDSAssociationUpdate : NSObject

// MARK: Properties

@property (nonatomic, assign)	MDSAssociationUpdateAction	action;
@property (nonatomic, strong)	NSString*					fromDocumentID;
@property (nonatomic, strong)	NSString*					toDocumentID;

// MARK: Instance methods

- (instancetype) initWithAction:(MDSAssociationUpdateAction) action
		fromDocumentID:(NSString*) fromDocumentID toDocumentID:(NSString*) toDocumentID;

@end

typedef	NSArray<MDSAssociationUpdate*>	MDSAssociationUpdateArray;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSCacheValueInfo

@class ObjCMDSValueInfo;
@class MDSDocumentValueInfo;

@interface MDSCacheValueInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	ObjCMDSValueInfo*		valueInfo;
@property (nonatomic, strong)	MDSDocumentValueInfo*	documentValueInfo;

// MARK: Instance methods

- (instancetype) initWithValueInfo:(ObjCMDSValueInfo*) valueInfo
		documentValueInfo:(MDSDocumentValueInfo*) documentValueInfo;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentAttachmentInfo

@interface MDSDocumentAttachmentInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*						_id;
@property (nonatomic, assign)	NSInteger						revision;
@property (nonatomic, strong)	NSDictionary<NSString*, id>*	info;

@end

typedef	NSDictionary<NSString*, MDSDocumentAttachmentInfo*>	MDSDocumentAttachmentInfoByID;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentCreateInfo

@interface MDSDocumentCreateInfo : NSObject

// MARK: Properties

@property (nonatomic, nullable, strong)	NSString*		documentID;
@property (nonatomic, nullable, strong)	NSDate*			creationDate;
@property (nonatomic, nullable, strong)	NSDate*			modificationDate;
@property (nonatomic, strong)			NSDictionary*	propertyMap;

// MARK: Instance methods

- (instancetype) initWithDocumentID:(nullable NSString*) documentID creationDate:(nullable NSDate*) creationDate
		modificationDate:(nullable NSDate*) modificationDate propertyMap:(NSDictionary*) propertyMap;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentFullInfo

@interface MDSDocumentFullInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*						documentID;
@property (nonatomic, assign)	NSInteger						revision;
@property (nonatomic, assign)	BOOL							active;
@property (nonatomic, strong)	NSDate*							creationDate;
@property (nonatomic, strong)	NSDate*							modificationDate;
@property (nonatomic, strong)	NSDictionary*					propertyMap;
@property (nonatomic, strong)	MDSDocumentAttachmentInfoByID*	attachmentInfoByID;

@end

typedef	NSArray<MDSDocumentFullInfo*>					MDSDocumentFullInfoArray;
typedef NSDictionary<NSString*, MDSDocumentFullInfo*>	MDSDocumentFullInfoDictionary;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentOverviewInfo

@interface MDSDocumentOverviewInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	documentID;
@property (nonatomic, assign)	NSInteger	revision;
@property (nonatomic, strong)	NSDate*		creationDate;
@property (nonatomic, strong)	NSDate*		modificationDate;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentRevisionInfo

@interface MDSDocumentRevisionInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	documentID;
@property (nonatomic, assign)	NSInteger	revision;

@end

typedef	NSArray<MDSDocumentRevisionInfo*>					MDSDocumentRevisionInfoArray;
typedef NSDictionary<NSString*, MDSDocumentRevisionInfo*>	MDSDocumentRevisionInfoDictionary;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentUpdateInfo

@interface MDSDocumentUpdateInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*						documentID;
@property (nonatomic, strong)	NSDictionary<NSString*, id>*	updated;
@property (nonatomic, strong)	NSSet<NSString*>*				removed;
@property (nonatomic, assign)	BOOL							active;

// MARK: Instance methods

- (instancetype) initWithDocumentID:(NSString*) documentID updated:(NSDictionary<NSString*, id>*) updated
		removed:(NSSet<NSString*>*) removed active:(BOOL) active;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentValueInfo

@interface MDSDocumentValueInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	selector;

// MARK: Instance methods

- (instancetype) initWithSelector:(NSString*) selector;

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - ObjCMDSValueType

typedef NS_ENUM(NSInteger) {
	kObjCMDSValueTypeInteger,
} ObjCMDSValueType;

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - ObjCMDSValueInfo

@interface ObjCMDSValueInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*			name;
@property (nonatomic, assign)	ObjCMDSValueType	valueType;

// MARK: Instance methods

- (instancetype) initWithName:(NSString*) name valueType:(ObjCMDSValueType) valueType;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC : NSObject

// MARK: Instance methods

- (void) completeSetup;

- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error;
- (BOOL) associationGetNamed:(NSString*) name
		outAssociationItems:(MDSAssociationItemArray* _Nullable * _Nullable) outAssociationItems
		error:(NSError**) error;
- (BOOL) associationGetDocumentRevisionInfosWithTotalCountNamed:(NSString*) name
		fromDocumentID:(NSString*) fromDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error;
- (BOOL) associationGetDocumentRevisionInfosWithTotalCountNamed:(NSString*) name
		toDocumentID:(NSString*) toDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error;
- (BOOL) associationGetDocumentFullInfosWithTotalCountNamed:(NSString*) name
		fromDocumentID:(NSString*) fromDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error;
- (BOOL) associationGetDocumentFullInfosWithTotalCountNamed:(NSString*) name
		toDocumentID:(NSString*) toDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error;
- (BOOL) associationGetValuesNamed:(NSString*) name
		associationGetValueAction:(MDSAssociationGetValueAction) associationGetValueAction
		fromDocumentIDs:(NSArray<NSString*>*) fromDocumentIDs cacheName:(NSString*) cacheName
		cachedValueNames:(NSArray<NSString*>*) cachedValueNames outInfo:(id _Nullable * _Nullable) outInfo
		error:(NSError**) error;
- (BOOL) associationUpdateNamed:(NSString*) name associationUpdates:(MDSAssociationUpdateArray*) associationUpdates
		error:(NSError**) error;

- (BOOL) cacheRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties
		cacheValueInfos:(NSArray<MDSCacheValueInfo*>*) cacheValueInfos error:(NSError**) error;
- (BOOL) cacheGetValuesNamed:(NSString*) name valueNames:(NSArray<NSString*>*) valueNames
		documentIDs:(nullable NSArray<NSString*>*) documentIDs
		outInfos:(NSArray<NSDictionary*>* _Nullable * _Nullable) outInfos error:(NSError**) error;
- (BOOL) cacheGetStatusNamed:(NSString*) name error:(NSError**) error;

- (BOOL) collectionRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties isUpToDate:(BOOL) isUpToDate
		isIncludedInfo:(NSDictionary<NSString*, id>*) isIncludedInfo isIncludedSelector:(NSString*) isIncludedSelector
		checkRelevantProperties:(BOOL) checkRelevantProperties error:(NSError**) error;
- (BOOL) collectionGetDocumentCountNamed:(NSString*) name outDocumentCount:(NSUInteger*) outDocumentCount
		error:(NSError**) error;
- (BOOL) collectionGetDocumentRevisionInfosNamed:(NSString*) name startIndex:(NSInteger) startIndex
		count:(nullable NSNumber*) count
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error;
- (BOOL) collectionGetDocumentFullInfosNamed:(NSString*) name startIndex:(NSInteger) startIndex
		count:(nullable NSNumber*) count
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error;

- (BOOL) documentCreateDocumentType:(NSString*) documentType
		documentCreateInfos:(NSArray<MDSDocumentCreateInfo*>*) documentCreateInfos
		outDocumentOverviewInfos:(NSArray<MDSDocumentOverviewInfo*>* _Nullable * _Nonnull) outDocumentOverviewInfos
		error:(NSError**) error;
- (BOOL) documentGetCountDocumentType:(NSString*) documentType outCount:(NSUInteger*) outCount error:(NSError**) error;
- (BOOL) documentRevisionInfosDocumentType:(NSString*) documentType documentIDs:(NSArray<NSString*>*) documentIDs
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error;
- (BOOL) documentRevisionInfosDocumentType:(NSString*) documentType sinceRevision:(NSInteger) sinceRevision
		count:(nullable NSNumber*) count
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) documentRevisionInfos
		error:(NSError**) error;
- (BOOL) documentFullInfosDocumentType:(NSString*) documentType documentIDs:(NSArray<NSString*>*) documentIDs
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error;
- (BOOL) documentFullInfosDocumentType:(NSString*) documentType sinceRevision:(NSInteger) sinceRevision
		count:(nullable NSNumber*) count
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) documentFullInfos
		error:(NSError**) error;
- (BOOL) documentUpdateDocumentType:(NSString*) documentType
		documentUpdateInfos:(NSArray<MDSDocumentUpdateInfo*>*) documentUpdateInfos
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error;
- (BOOL) documentAttachmentAddDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		info:(NSDictionary<NSString*, id>*) info content:(NSData*) content
		outDocumentAttachmentInfo:(MDSDocumentAttachmentInfo* _Nullable * _Nullable) outDocumentAttachmentInfo
		error:(NSError**) error;
- (BOOL) documentAttachmentContentDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID outData:(NSData* _Nullable * _Nullable) outData error:(NSError**) error;
- (BOOL) documentAttachmentUpdateDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID updatedInfo:(NSDictionary<NSString*, id>*) updatedInfo
		updatedContent:(NSData*) updatedContent outRevision:(NSInteger* _Nullable) outRevision error:(NSError**) error;
- (BOOL) documentAttachmentRemoveDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID error:(NSError**) error;

- (BOOL) indexRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties keysInfo:(NSDictionary<NSString*, id>*) keysInfo
		keysSelector:(NSString*) keysSelector error:(NSError**) error;
- (BOOL) indexGetDocumentRevisionInfosNamed:(NSString*) name keys:(NSArray<NSString*>*) keys
		outDocumentRevisionInfoDictionary:(MDSDocumentRevisionInfoDictionary* _Nullable * _Nullable)
				outDocumentRevisionInfoDictionary
		error:(NSError**) error;
- (BOOL) indexGetDocumentFullInfosNamed:(NSString*) name keys:(NSArray<NSString*>*) keys
		outDocumentFullInfoDictionary:(MDSDocumentFullInfoDictionary* _Nullable * _Nullable)
				outDocumentFullInfoDictionary
		error:(NSError**) error;
- (BOOL) indexGetStatusNamed:(NSString*) name error:(NSError**) error;

- (BOOL) infoGetKeys:(NSArray<NSString*>*) keys outInfo:(NSDictionary<NSString*, id>* _Nullable * _Nullable) outInfo
		error:(NSError**) error;
- (BOOL) infoSet:(NSDictionary<NSString*, id>*) info error:(NSError**) error;

- (BOOL) internalSet:(NSDictionary<NSString*, id>*) info error:(NSError**) error;

@end

NS_ASSUME_NONNULL_END
