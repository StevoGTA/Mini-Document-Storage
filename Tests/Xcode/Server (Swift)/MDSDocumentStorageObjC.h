//
//  MDSDocumentStorageObjC.h
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/23/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociationItem

@interface MDSAssociationItem : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	fromDocumentID;
@property (nonatomic, strong)	NSString*	toDocumentID;

// MARK: Instance methods

- (instancetype) initWithFromDocumentID:(NSString*) fromDocumentID toDocumentID:(NSString*) toDocumentID;

@end

typedef	NSArray<MDSAssociationItem*>	MDSAssociationItemArray;

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociationUpdate

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
// MARK: MDSDocumentOverviewInfo

@interface MDSDocumentOverviewInfo : NSObject

// MARK: Properties

@property (nonatomic, strong)	NSString*	documentID;
@property (nonatomic, assign)	NSInteger	revision;
@property (nonatomic, strong)	NSDate*		creationDate;
@property (nonatomic, strong)	NSDate*		modificationDate;

@end

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentCreateInfo

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
// MARK: MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC : NSObject

// MARK: Instance methods

- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error;
- (BOOL) associationGetNamed:(NSString*) name
		associationItems:(MDSAssociationItemArray* _Nullable * _Nullable) associationItems error:(NSError**) error;
- (BOOL) associationUpdateNamed:(NSString*) name associationUpdates:(MDSAssociationUpdateArray*) associationUpdates
		error:(NSError**) error;

- (BOOL) documentCreateDocumentType:(NSString*) documentType
		documentCreateInfos:(NSArray<MDSDocumentCreateInfo*>*) documentCreateInfos
		documentOverviewInfos:(NSArray<MDSDocumentOverviewInfo*>* _Nullable * _Nonnull) documentOverviewInfos
		error:(NSError**) error;

@end

NS_ASSUME_NONNULL_END
