//
//  MDSDocumentStorageObjC.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/24/23.
//

#import "MDSDocumentStorageObjC.h"

#import "CCoreFoundation.h"
#import "CMDSDocumentStorageServer.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociationItem

@implementation MDSAssociationItem

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithFromDocumentID:(NSString*) fromDocumentID toDocumentID:(NSString*) toDocumentID
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.fromDocumentID = fromDocumentID;
		self.toDocumentID = toDocumentID;
	}

	return self;
}

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithAssociationItem:(const CMDSAssociation::Item&) associationItem
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.fromDocumentID = (__bridge NSString*) associationItem.getFromDocumentID().getOSString();
		self.toDocumentID = (__bridge NSString*) associationItem.getToDocumentID().getOSString();
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSAssociationUpdate

@implementation MDSAssociationUpdate

// MARK: Property methods

//----------------------------------------------------------------------------------------------------------------------
- (CMDSAssociation::Update) associationUpdate
{
	// Check action
		switch (self.action) {
			case kMDSAssociationUpdateActionAdd:
				// Add
				return CMDSAssociation::Update::add(CString((__bridge CFStringRef) self.fromDocumentID),
						CString((__bridge CFStringRef) self.toDocumentID));

			case kMDSAssociationUpdateActionRemove:
				// Remove
				return CMDSAssociation::Update::remove(CString((__bridge CFStringRef) self.fromDocumentID),
						CString((__bridge CFStringRef) self.toDocumentID));
		}
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithAction:(MDSAssociationUpdateAction) action
		fromDocumentID:(NSString*) fromDocumentID toDocumentID:(NSString*) toDocumentID
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.action = action;
		self.fromDocumentID = fromDocumentID;
		self.toDocumentID = toDocumentID;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSCacheValueInfo

@implementation MDSCacheValueInfo

// MARK: Property methods

//----------------------------------------------------------------------------------------------------------------------
- (CMDSDocumentStorage::CacheValueInfo) documentStorageCacheValueInfo
{
	// Setup
	CString	valueType;
	switch (self.valueInfo.valueType) {
		case kObjCMDSValueTypeInteger:	valueType = SMDSValueType::mInteger;	break;
	}

	return CMDSDocumentStorage::CacheValueInfo(
			SMDSValueInfo(CString((__bridge CFStringRef) self.valueInfo.name), valueType),
			CString((__bridge CFStringRef) self.documentValueInfo.selector));
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithValueInfo:(ObjCMDSValueInfo*) valueInfo
		documentValueInfo:(MDSDocumentValueInfo*) documentValueInfo
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.valueInfo = valueInfo;
		self.documentValueInfo = documentValueInfo;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentAttachmentInfo

@implementation MDSDocumentAttachmentInfo

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentAttachmentInfo:(const CMDSDocument::AttachmentInfo&) documentAttachmentInfo
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self._id = (__bridge NSString*) documentAttachmentInfo.getID().getOSString();
		self.revision = documentAttachmentInfo.getRevision();
		self.info =
				(NSDictionary*)
						CFBridgingRelease(CCoreFoundation::createDictionaryRefFrom(documentAttachmentInfo.getInfo()));
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentCreateInfo

@implementation MDSDocumentCreateInfo

// MARK: Property methods

//----------------------------------------------------------------------------------------------------------------------
- (CMDSDocument::CreateInfo) documentCreateInfo
{
	// Get info
	NSString*	_Nullable	documentID = self.documentID;
	NSDate*		_Nullable	creationDate = self.creationDate;
	NSDate*		_Nullable	modificationDate = self.modificationDate;

	return CMDSDocument::CreateInfo(
			(documentID != nil) ? OV<CString>(CString((__bridge CFStringRef) documentID)) : OV<CString>(),
			(creationDate != nil) ?
					OV<UniversalTime>(creationDate.timeIntervalSinceReferenceDate) : OV<UniversalTime>(),
			(modificationDate != nil) ?
					OV<UniversalTime>(modificationDate.timeIntervalSinceReferenceDate) : OV<UniversalTime>(),
			CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) self.propertyMap));
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentID:(nullable NSString*) documentID creationDate:(nullable NSDate*) creationDate
		modificationDate:(nullable NSDate*) modificationDate propertyMap:(NSDictionary*) propertyMap
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.documentID = documentID;
		self.creationDate = creationDate;
		self.modificationDate = modificationDate;
		self.propertyMap = propertyMap;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentFullInfo

@implementation MDSDocumentFullInfo

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentFullInfo:(const CMDSDocument::FullInfo&) documentFullInfo
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.documentID = (__bridge NSString*) documentFullInfo.getDocumentID().getOSString();
		self.revision = documentFullInfo.getRevision();
		self.active = documentFullInfo.getActive();
		self.creationDate =
				[NSDate dateWithTimeIntervalSinceReferenceDate:documentFullInfo.getCreationUniversalTime()];
		self.modificationDate =
				[NSDate dateWithTimeIntervalSinceReferenceDate:documentFullInfo.getModificationUniversalTime()];
		self.propertyMap =
				(NSDictionary*)
						CFBridgingRelease(CCoreFoundation::createDictionaryRefFrom(documentFullInfo.getPropertyMap()));

		const	TSet<CString>	keys = documentFullInfo.getAttachmentInfoByID().getKeys();
		self.attachmentInfoByID = [[NSMutableDictionary alloc] init];
		for (TIteratorS<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
			[(NSMutableDictionary*) self.attachmentInfoByID
					setObject:
							[[MDSDocumentAttachmentInfo alloc]
									initWithDocumentAttachmentInfo:*documentFullInfo.getAttachmentInfoByID()[*iterator]]
					forKey:(__bridge NSString*) iterator->getOSString()];
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentOverviewInfo

@implementation MDSDocumentOverviewInfo

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentOverviewInfo:(const CMDSDocument::OverviewInfo&) documentOverviewInfo
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.documentID = (__bridge NSString*) documentOverviewInfo.getDocumentID().getOSString();
		self.revision = documentOverviewInfo.getRevision();
		self.creationDate =
				[NSDate dateWithTimeIntervalSinceReferenceDate:documentOverviewInfo.getCreationUniversalTime()];
		self.modificationDate =
				[NSDate dateWithTimeIntervalSinceReferenceDate:documentOverviewInfo.getModificationUniversalTime()];
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentRevisionInfo

@implementation MDSDocumentRevisionInfo

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentRevisionInfo:(const CMDSDocument::RevisionInfo&) documentRevisionInfo
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.documentID = (__bridge NSString*) documentRevisionInfo.getDocumentID().getOSString();
		self.revision = documentRevisionInfo.getRevision();
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentUpdateInfo

@implementation MDSDocumentUpdateInfo

// MARK: Property methods

//----------------------------------------------------------------------------------------------------------------------
- (CMDSDocument::UpdateInfo) documentUpdateInfo
{
	return CMDSDocument::UpdateInfo(CString((__bridge CFStringRef) self.documentID),
			CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) self.updated),
			CCoreFoundation::setOfStringsFrom((__bridge CFSetRef) self.removed), self.active);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithDocumentID:(NSString*) documentID updated:(NSDictionary<NSString*, id>*) updated
		removed:(NSSet<NSString*>*) removed active:(BOOL) active
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.documentID = documentID;
		self.updated = updated;
		self.removed = removed;
		self.active = active;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------

// MARK: - MDSDocumentValueInfo

@implementation MDSDocumentValueInfo

// MARK: Instance methods

- (instancetype) initWithSelector:(NSString*) selector
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.selector = selector;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - ObjCMDSValueInfo

@implementation ObjCMDSValueInfo

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithName:(NSString*) name valueType:(ObjCMDSValueType) valueType
{
	// Do super
	self = [super init];
	if (self) {
		// Store
		self.name = name;
		self.valueType = valueType;
	}

	return self;
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: Local proc declarations

static	bool			sDocumentPropertyIsValue(const CString& documentType, const I<CMDSDocument>& document,
								const CDictionary& info, CMDSDocumentStorageServer* documentStorageServer);
static	TArray<CString>	sKeysForDocumentProperty(const CString& documentType, const I<CMDSDocument>& document,
								const CDictionary& info, CMDSDocumentStorageServer* documentStorageServer);
static	SValue			sIntegerValueForProperty(const CString& documentType, const I<CMDSDocument>& document,
								const CString& property, CMDSDocumentStorageServer* documentStorageServer);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC ()

@property (nonatomic, assign)	CMDSDocumentStorageServer*	documentStorageServer;

@end

@implementation MDSDocumentStorageObjC

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (void) dealloc
{
	// Cleanup
	Delete(self.documentStorageServer);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (void) completeSetup
{
	// Complete setup
	self.documentStorageServer->registerDocumentIsIncludedPerformerInfos(
			TSArray<CMDSDocumentStorage::DocumentIsIncludedPerformerInfo>(
					CMDSDocumentStorage::DocumentIsIncludedPerformerInfo(
							CMDSDocument::IsIncludedPerformer(CString(OSSTR("documentPropertyIsValue()")),
									(CMDSDocument::IsIncludedPerformer::Proc) sDocumentPropertyIsValue,
									self.documentStorageServer),
							true)));
	self.documentStorageServer->registerDocumentKeysPerformers(
			TSArray<CMDSDocument::KeysPerformer>(
					CMDSDocument::KeysPerformer(CString(OSSTR("keysForDocumentProperty()")),
							(CMDSDocument::KeysPerformer::Proc) sKeysForDocumentProperty,
							self.documentStorageServer)));
	self.documentStorageServer->registerValueInfos(
			TSArray<CMDSDocument::ValueInfo>(
					CMDSDocument::ValueInfo(CString(OSSTR("integerValueForProperty()")),
							(CMDSDocument::ValueInfo::Proc) sIntegerValueForProperty,
							self.documentStorageServer)));
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error
{
	// Register association
	OV<SError>	cppError =
						self.documentStorageServer->associationRegister(CString((__bridge CFStringRef) name),
								CString((__bridge CFStringRef) fromDocumentType),
								CString((__bridge CFStringRef) toDocumentType));

	return [self composeResultsFrom:cppError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetNamed:(NSString*) name
		outAssociationItems:(MDSAssociationItemArray* _Nullable * _Nullable) outAssociationItems error:(NSError**) error
{
	// Get all associations
	TVResult<TArray<CMDSAssociation::Item> >	associationItemsResult =
														self.documentStorageServer->associationGet(
																CString((__bridge CFStringRef) name));
	if (associationItemsResult.hasError()) {
		// Error
		*error = [self errorFrom:associationItemsResult.getError()];

		return NO;
	}

	// Prepare results
	*outAssociationItems = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItemsResult.getValue().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outAssociationItems
				addObject:[[MDSAssociationItem alloc] initWithAssociationItem:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetDocumentRevisionInfosWithTotalCountNamed:(NSString*) name
		fromDocumentID:(NSString*) fromDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
			documentStorageServerDocumentRevisionInfosWithTotalCount =
					self.documentStorageServer->associationGetDocumentRevisionInfosFrom(
							CString((__bridge CFStringRef) name), CString((__bridge CFStringRef) fromDocumentID),
							(UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentRevisionInfosWithTotalCount.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentRevisionInfosWithTotalCount.getError()];

		return NO;
	}

	// Prepare results
	*outTotalCount =  documentStorageServerDocumentRevisionInfosWithTotalCount->getTotalCount();

	*outDocumentRevisionInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::RevisionInfo> iterator =
					documentStorageServerDocumentRevisionInfosWithTotalCount->getDocumentRevisionInfos().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentRevisionInfos
				addObject:[[MDSDocumentRevisionInfo alloc] initWithDocumentRevisionInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetDocumentRevisionInfosWithTotalCountNamed:(NSString*) name
		toDocumentID:(NSString*) toDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
			documentStorageServerDocumentRevisionInfosWithTotalCount =
					self.documentStorageServer->associationGetDocumentRevisionInfosTo(
							CString((__bridge CFStringRef) name), CString((__bridge CFStringRef) toDocumentID),
							(UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentRevisionInfosWithTotalCount.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentRevisionInfosWithTotalCount.getError()];

		return NO;
	}

	// Prepare results
	*outTotalCount = documentStorageServerDocumentRevisionInfosWithTotalCount->getTotalCount();

	*outDocumentRevisionInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::RevisionInfo> iterator =
					documentStorageServerDocumentRevisionInfosWithTotalCount->getDocumentRevisionInfos().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentRevisionInfos
				addObject:[[MDSDocumentRevisionInfo alloc] initWithDocumentRevisionInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetDocumentFullInfosWithTotalCountNamed:(NSString*) name
		fromDocumentID:(NSString*) fromDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>
			documentStorageServerDocumentFullInfosWithTotalCount =
					self.documentStorageServer->associationGetDocumentFullInfosFrom(
							CString((__bridge CFStringRef) name), CString((__bridge CFStringRef) fromDocumentID),
							(UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentFullInfosWithTotalCount.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentFullInfosWithTotalCount.getError()];

		return NO;
	}

	// Prepare results
	*outTotalCount = documentStorageServerDocumentFullInfosWithTotalCount->getTotalCount();

	*outDocumentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator =
					documentStorageServerDocumentFullInfosWithTotalCount->getDocumentFullInfos().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetDocumentFullInfosWithTotalCountNamed:(NSString*) name
		toDocumentID:(NSString*) toDocumentID startIndex:(NSInteger) startIndex count:(nullable NSNumber*) count
		totalCount:(NSInteger*) outTotalCount
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>
			documentStorageServerDocumentFullInfosWithTotalCount =
					self.documentStorageServer->associationGetDocumentFullInfosTo(
							CString((__bridge CFStringRef) name), CString((__bridge CFStringRef) toDocumentID),
							(UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentFullInfosWithTotalCount.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentFullInfosWithTotalCount.getError()];

		return NO;
	}

	// Prepare results
	*outTotalCount = documentStorageServerDocumentFullInfosWithTotalCount->getTotalCount();

	*outDocumentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator =
					documentStorageServerDocumentFullInfosWithTotalCount->getDocumentFullInfos().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetValuesNamed:(NSString*) name
		associationGetValueAction:(MDSAssociationGetValueAction) associationGetValueAction
		fromDocumentIDs:(NSArray<NSString*>*) fromDocumentIDs cacheName:(NSString*) cacheName
		cachedValueNames:(NSArray<NSString*>*) cachedValueNames outInfo:(id _Nullable * _Nullable) outInfo
		error:(NSError**) error
{
	// Setup
	CMDSAssociation::GetValueAction	cppAssociationGetValueAction;
	switch (associationGetValueAction) {
		case kMDSAssociationGetValueActionDetail:	cppAssociationGetValueAction = CMDSAssociation::kGetValueActionDetail;	break;
		case kMDSAssociationGetValueActionSum:		cppAssociationGetValueAction = CMDSAssociation::kGetValueActionSum;		break;
	}

	// Get values
	TVResult<SValue>	value =
								self.documentStorageServer->associationGetValues(CString((__bridge CFStringRef) name),
										cppAssociationGetValueAction,
										CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) fromDocumentIDs),
										CString((__bridge CFStringRef) cacheName),
										CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) cachedValueNames));
	if (value.hasError()) {
		// Error
		*error = [self errorFrom:value.getError()];

		return NO;
	}

	// Prepare results
	switch (associationGetValueAction) {
		case kMDSAssociationGetValueActionDetail:
			// Detail
			*outInfo =
					(NSArray*) CFBridgingRelease(CCoreFoundation::createArrayRefFrom(value->getArrayOfDictionaries()));
			break;

		case kMDSAssociationGetValueActionSum:
			// Sum
			*outInfo =
					(NSArray*) CFBridgingRelease(CCoreFoundation::createDictionaryRefFrom(value->getDictionary()));
			break;
	}

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationUpdateNamed:(NSString*) name associationUpdates:(MDSAssociationUpdateArray*) associationUpdates
		error:(NSError**) error
{
	// Setup
	TNArray<CMDSAssociation::Update>	cppAssociationUpdates;
	for (MDSAssociationUpdate* associationUpdate in associationUpdates)
		// Add
		cppAssociationUpdates += associationUpdate.associationUpdate;

	// Update association
	OV<SError>	cppError =
						self.documentStorageServer->associationUpdate(CString((__bridge CFStringRef) name),
								cppAssociationUpdates);

	return [self composeResultsFrom:cppError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) cacheRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties
		cacheValueInfos:(NSArray<MDSCacheValueInfo*>*) cacheValueInfos error:(NSError**) error
{
	// Setup
	TNArray<CMDSDocumentStorage::CacheValueInfo>	cppCacheValueInfos;
	for (MDSCacheValueInfo* cacheValueInfo in cacheValueInfos)
		// Add
		cppCacheValueInfos += cacheValueInfo.documentStorageCacheValueInfo;

	// Register cache
	OV<SError>	cppError =
						self.documentStorageServer->cacheRegister(CString((__bridge CFStringRef) name),
								CString((__bridge CFStringRef) documentType),
								CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) relevantProperties),
								cppCacheValueInfos);

	return [self composeResultsFrom:cppError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) cacheGetValuesNamed:(NSString*) name valueNames:(NSArray<NSString*>*) valueNames
		documentIDs:(nullable NSArray<NSString*>*) documentIDs
		outInfos:(NSArray<NSDictionary*>* _Nullable * _Nullable) outInfos error:(NSError**) error
{
	// Setup
	TNArray<CString>	cppValueNames;
	for (NSString* valueName in valueNames)
		// Add
		cppValueNames += CString((__bridge CFStringRef) valueName);

	OV<TArray<CString> >	cppDocumentIDs;
	if (documentIDs != nil) {
		// Iterate documentIDs
		TNArray<CString>	cppDocumentIDs_;
		for (NSString* documentID in documentIDs)
			// Add
			cppDocumentIDs_ += CString((__bridge CFStringRef) documentID);

		// Update
		cppDocumentIDs.setValue(cppDocumentIDs_);
	}

	// Get values
	TVResult<TArray<CDictionary> >	infos =
											self.documentStorageServer->cacheGetValues(
													CString((__bridge CFStringRef) name), cppValueNames,
													cppDocumentIDs);
	if (infos.hasError()) {
		// Error
		*error = [self errorFrom:infos.getError()];

		return NO;
	}

	// Compose results
	*outInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CDictionary> iterator = infos->getIterator(); iterator.hasValue(); iterator.advance())
		// Add result
		[(NSMutableArray*) *outInfos
				addObject:(NSDictionary*) CFBridgingRelease(CCoreFoundation::createDictionaryRefFrom(*iterator))];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) collectionRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties isUpToDate:(BOOL) isUpToDate
		isIncludedInfo:(NSDictionary<NSString*, id>*) isIncludedInfo isIncludedSelector:(NSString*) isIncludedSelector
		checkRelevantProperties:(BOOL) checkRelevantProperties error:(NSError**) error
{
	// Register collection
	OV<SError>	cppError =
						self.documentStorageServer->collectionRegister(CString((__bridge CFStringRef) name),
								CString((__bridge CFStringRef) documentType),
								CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) relevantProperties),
								isUpToDate, CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) isIncludedInfo),
								CString((__bridge CFStringRef) isIncludedSelector), checkRelevantProperties);

	return [self composeResultsFrom:cppError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) collectionGetDocumentCountNamed:(NSString*) name outDocumentCount:(NSUInteger*) outDocumentCount
		error:(NSError**) error
{
	// Get count
	TVResult<UInt32>	documentCount =
								self.documentStorageServer->collectionGetDocumentCount(
										CString((__bridge CFStringRef) name));
	if (documentCount.hasError()) {
		// Error
		*error = [self errorFrom:documentCount.getError()];

		return NO;
	}

	// Store
	*outDocumentCount = *documentCount;

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) collectionGetDocumentRevisionInfosNamed:(NSString*) name startIndex:(NSInteger) startIndex
		count:(nullable NSNumber*) count
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) outDocumentRevisionInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosResult>
			documentStorageServerDocumentRevisionInfos =
					self.documentStorageServer->collectionGetDocumentRevisionInfos(
							CString((__bridge CFStringRef) name), (UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentRevisionInfos.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentRevisionInfos.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentRevisionInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::RevisionInfo> iterator =
					documentStorageServerDocumentRevisionInfos->getValue().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentRevisionInfos
				addObject:[[MDSDocumentRevisionInfo alloc] initWithDocumentRevisionInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) collectionGetDocumentFullInfosNamed:(NSString*) name startIndex:(NSInteger) startIndex
		count:(nullable NSNumber*) count
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error
{
	// Get results
	TVResult<CMDSDocumentStorageServer::DocumentFullInfosResult>
			documentStorageServerDocumentFullInfos =
					self.documentStorageServer->collectionGetDocumentFullInfos(CString((__bridge CFStringRef) name),
							(UInt32) startIndex,
							(count != nil) ? OV<UInt32>((UInt32) count.integerValue) : OV<UInt32>());
	if (documentStorageServerDocumentFullInfos.hasError()) {
		// Error
		*error = [self errorFrom:documentStorageServerDocumentFullInfos.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator = documentStorageServerDocumentFullInfos->getValue().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentCreateDocumentType:(NSString*) documentType
		documentCreateInfos:(NSArray<MDSDocumentCreateInfo*>*) documentCreateInfos
		outDocumentOverviewInfos:(NSArray<MDSDocumentOverviewInfo*>* _Nullable * _Nonnull) outDocumentOverviewInfos
		error:(NSError**) error
{
	// Setup
	TNArray<CMDSDocument::CreateInfo>	cppDocumentCreateInfos;
	for (MDSDocumentCreateInfo* documentCreateInfo in documentCreateInfos)
		// Add
		cppDocumentCreateInfos += documentCreateInfo.documentCreateInfo;

	// Create documents
	TVResult<TArray<CMDSDocument::CreateResultInfo> >	result =
																self.documentStorageServer->documentCreate(
																		CString((__bridge CFStringRef) documentType),
																		cppDocumentCreateInfos);

	// Handle results
	if (result.hasValue()) {
		// Success
		*outDocumentOverviewInfos = [[NSMutableArray<MDSDocumentOverviewInfo*> alloc] init];
		for (TIteratorD<CMDSDocument::CreateResultInfo> iterator = result.getValue().getIterator(); iterator.hasValue();
				iterator.advance())
			// Add Overview Info
			[(NSMutableArray<MDSDocumentOverviewInfo*>*) *outDocumentOverviewInfos
					addObject:
							[[MDSDocumentOverviewInfo alloc]
									initWithDocumentOverviewInfo:*iterator->getOverviewInfo()]];

		return YES;
	} else {
		// Error
		*error = [self errorFrom:result.getError()];

		return NO;
	}
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentGetCountDocumentType:(NSString*) documentType outCount:(NSUInteger*) outCount error:(NSError**) error
{
	// Get count
	TVResult<UInt32>	count =
								self.documentStorageServer->documentGetCount(
										CString((__bridge CFStringRef) documentType));
	if (count.hasError()) {
		// Error
		*error = [self errorFrom:count.getError()];

		return NO;
	}

	// Store
	*outCount = *count;

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentRevisionInfosDocumentType:(NSString*) documentType documentIDs:(NSArray<NSString*>*) documentIDs
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) documentRevisionInfos
		error:(NSError**) error
{
	// Get document revision infos
	CMDSDocumentStorageServer::DocumentRevisionInfosResult	documentRevisionInfosResult =
																	self.documentStorageServer->documentRevisionInfos(
																			CString((__bridge CFStringRef) documentType),
																			CCoreFoundation::arrayOfStringsFrom(
																					(__bridge CFArrayRef) documentIDs));
	if (documentRevisionInfosResult.hasError()) {
		// Error
		*error = [self errorFrom:documentRevisionInfosResult.getError()];

		return NO;
	}

	// Prepare results
	*documentRevisionInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::RevisionInfo> iterator = documentRevisionInfosResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *documentRevisionInfos
				addObject:[[MDSDocumentRevisionInfo alloc] initWithDocumentRevisionInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentRevisionInfosDocumentType:(NSString*) documentType sinceRevision:(NSInteger) sinceRevision
		count:(nullable NSNumber*) count
		outDocumentRevisionInfos:(MDSDocumentRevisionInfoArray* _Nullable * _Nullable) documentRevisionInfos
		error:(NSError**) error
{
	// Get document revision infos
	CMDSDocumentStorageServer::DocumentRevisionInfosResult	documentRevisionInfosResult =
																	self.documentStorageServer->documentRevisionInfos(
																			CString((__bridge CFStringRef) documentType),
																			(UInt32) sinceRevision,
																			(count != nil) ?
																					OV<UInt32>((UInt32) count.integerValue) :
																					OV<UInt32>());
	if (documentRevisionInfosResult.hasError()) {
		// Error
		*error = [self errorFrom:documentRevisionInfosResult.getError()];

		return NO;
	}

	// Prepare results
	*documentRevisionInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::RevisionInfo> iterator = documentRevisionInfosResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableArray*) *documentRevisionInfos
				addObject:[[MDSDocumentRevisionInfo alloc] initWithDocumentRevisionInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentFullInfosDocumentType:(NSString*) documentType documentIDs:(NSArray<NSString*>*) documentIDs
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) documentFullInfos error:(NSError**) error
{
	// Get document full infos
	CMDSDocumentStorageServer::DocumentFullInfosResult	documentFullInfosResult =
																self.documentStorageServer->documentFullInfos(
																		CString((__bridge CFStringRef) documentType),
																		CCoreFoundation::arrayOfStringsFrom(
																				(__bridge CFArrayRef) documentIDs));
	if (documentFullInfosResult.hasError()) {
		// Error
		*error = [self errorFrom:documentFullInfosResult.getError()];

		return NO;
	}

	// Prepare results
	*documentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator = documentFullInfosResult->getIterator(); iterator.hasValue();
			iterator.advance())
		// Add object
		[(NSMutableArray*) *documentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentFullInfosDocumentType:(NSString*) documentType sinceRevision:(NSInteger) sinceRevision
		count:(nullable NSNumber*) count
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) documentFullInfos error:(NSError**) error
{
	// Get document full infos
	CMDSDocumentStorageServer::DocumentFullInfosResult	documentFullInfosResult =
																self.documentStorageServer->documentFullInfos(
																		CString((__bridge CFStringRef) documentType),
																		(UInt32) sinceRevision,
																		(count != nil) ?
																				OV<UInt32>((UInt32) count.integerValue) :
																				OV<UInt32>());
	if (documentFullInfosResult.hasError()) {
		// Error
		*error = [self errorFrom:documentFullInfosResult.getError()];

		return NO;
	}

	// Prepare results
	*documentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator = documentFullInfosResult->getIterator(); iterator.hasValue();
			iterator.advance())
		// Add object
		[(NSMutableArray*) *documentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentUpdateDocumentType:(NSString*) documentType
		documentUpdateInfos:(NSArray<MDSDocumentUpdateInfo*>*) documentUpdateInfos
		outDocumentFullInfos:(MDSDocumentFullInfoArray* _Nullable * _Nullable) outDocumentFullInfos
		error:(NSError**) error
{
	// Setup
	TNArray<CMDSDocument::UpdateInfo>	cppDocumentUpdateInfos;
	for (MDSDocumentUpdateInfo* documentUpdateInfo in documentUpdateInfos)
		// Add
		cppDocumentUpdateInfos += documentUpdateInfo.documentUpdateInfo;

	// Get document full infos
	CMDSDocumentStorageServer::DocumentFullInfosResult	documentFullInfosResult =
																self.documentStorageServer->documentUpdate(
																		CString((__bridge CFStringRef) documentType),
																		cppDocumentUpdateInfos);
	if (documentFullInfosResult.hasError()) {
		// Error
		*error = [self errorFrom:documentFullInfosResult.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentFullInfos = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSDocument::FullInfo> iterator = documentFullInfosResult->getIterator(); iterator.hasValue();
			iterator.advance())
		// Add object
		[(NSMutableArray*) *outDocumentFullInfos
				addObject:[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*iterator]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentAttachmentAddDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		info:(NSDictionary<NSString*, id>*) info content:(NSData*) content
		outDocumentAttachmentInfo:(MDSDocumentAttachmentInfo* _Nullable * _Nullable) outDocumentAttachmentInfo
		error:(NSError**) error
{
	// Add Document Attachment
	TVResult<CMDSDocument::AttachmentInfo>	documentAttachmentInfo =
													self.documentStorageServer->documentAttachmentAdd(
															CString((__bridge CFStringRef) documentType),
															CString((__bridge CFStringRef) documentID),
															CCoreFoundation::dictionaryFrom(
																	(__bridge CFDictionaryRef) info),
															CCoreFoundation::dataFrom((__bridge CFDataRef) content));
	if (documentAttachmentInfo.hasError()) {
		// Error
		*error = [self errorFrom:documentAttachmentInfo.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentAttachmentInfo =
			[[MDSDocumentAttachmentInfo alloc] initWithDocumentAttachmentInfo:*documentAttachmentInfo];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentAttachmentContentDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID outData:(NSData* _Nullable * _Nullable) outData error:(NSError**) error
{
	// Get Document Attachment content
	TVResult<CData>	data =
							self.documentStorageServer->documentAttachmentContent(
									CString((__bridge CFStringRef) documentType),
									CString((__bridge CFStringRef) documentID),
									CString((__bridge CFStringRef) attachmentID));
	if (data.hasError()) {
		// Error
		*error = [self errorFrom:data.getError()];

		return NO;
	}

	// Prepare result
	*outData = (NSData*) CFBridgingRelease(CCoreFoundation::createDataRefFrom(*data));

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentAttachmentUpdateDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID updatedInfo:(NSDictionary<NSString*, id>*) updatedInfo
		updatedContent:(NSData*) updatedContent outRevision:(NSInteger* _Nullable) outRevision error:(NSError**) error
{
	// Update Document Attachment
	TVResult<OV<UInt32> >	revision =
									self.documentStorageServer->documentAttachmentUpdate(
											CString((__bridge CFStringRef) documentType),
											CString((__bridge CFStringRef) documentID),
											CString((__bridge CFStringRef) attachmentID),
											CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) updatedInfo),
											CCoreFoundation::dataFrom((__bridge CFDataRef) updatedContent));
	if (revision.hasError()) {
		// Error
		*error = [self errorFrom:revision.getError()];

		return NO;
	}

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentAttachmentRemoveDocumentType:(NSString*) documentType documentID:(NSString*) documentID
		attachmentID:(NSString*) attachmentID error:(NSError**) error
{
	// Remove Document Attachment
	OV<SError>	cppError =
						self.documentStorageServer->documentAttachmentRemove(
								CString((__bridge CFStringRef) documentType),
								CString((__bridge CFStringRef) documentID),
								CString((__bridge CFStringRef) attachmentID));
	if (cppError.hasValue()) {
		// Error
		*error = [self errorFrom:*cppError];

		return NO;
	}

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) indexRegisterNamed:(NSString*) name documentType:(NSString*) documentType
		relevantProperties:(NSArray<NSString*>*) relevantProperties keysInfo:(NSDictionary<NSString*, id>*) keysInfo
		keysSelector:(NSString*) keysSelector error:(NSError**) error
{
	// Register index
	OV<SError>	cppError =
						self.documentStorageServer->indexRegister(CString((__bridge CFStringRef) name),
								CString((__bridge CFStringRef) documentType),
								CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) relevantProperties),
								CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) keysInfo),
								CString((__bridge CFStringRef) keysSelector));

	return [self composeResultsFrom:cppError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) indexGetDocumentRevisionInfosNamed:(NSString*) name keys:(NSArray<NSString*>*) keys
		outDocumentRevisionInfoDictionary:(MDSDocumentRevisionInfoDictionary* _Nullable * _Nullable)
				outDocumentRevisionInfoDictionary
		error:(NSError**) error
{
	// Setup
	TArray<CString>	keysArray = CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) keys);

	// Get infos
	TVResult<TDictionary<CMDSDocument::RevisionInfo> >	documentRevisionInfoDictionary =
																self.documentStorageServer->
																		indexGetDocumentRevisionInfos(
																				CString((__bridge CFStringRef) name),
																				keysArray);
	if (documentRevisionInfoDictionary.hasError()) {
		// Error
		*error = [self errorFrom:documentRevisionInfoDictionary.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentRevisionInfoDictionary = [[NSMutableDictionary alloc] init];
	for (TIteratorD<CString> iterator = keysArray.getIterator(); iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableDictionary*) *outDocumentRevisionInfoDictionary
				setObject:
						[[MDSDocumentRevisionInfo alloc]
								initWithDocumentRevisionInfo:*(*documentRevisionInfoDictionary)[*iterator]]
				forKey:(__bridge NSString*) iterator->getOSString()];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) indexGetDocumentFullInfosNamed:(NSString*) name keys:(NSArray<NSString*>*) keys
		outDocumentFullInfoDictionary:(MDSDocumentFullInfoDictionary* _Nullable * _Nullable)
				outDocumentFullInfoDictionary
		error:(NSError**) error
{
	// Setup
	TArray<CString>	keysArray = CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) keys);

	// Get infos
	TVResult<TDictionary<CMDSDocument::FullInfo> >	documentFullInfoDictionary =
															self.documentStorageServer->
																	indexGetDocumentFullInfos(
																			CString((__bridge CFStringRef) name),
																			keysArray);
	if (documentFullInfoDictionary.hasError()) {
		// Error
		*error = [self errorFrom:documentFullInfoDictionary.getError()];

		return NO;
	}

	// Prepare results
	*outDocumentFullInfoDictionary = [[NSMutableDictionary alloc] init];
	for (TIteratorD<CString> iterator = keysArray.getIterator(); iterator.hasValue(); iterator.advance())
		// Add object
		[(NSMutableDictionary*) *outDocumentFullInfoDictionary
				setObject:
						[[MDSDocumentFullInfo alloc] initWithDocumentFullInfo:*(*documentFullInfoDictionary)[*iterator]]
				forKey:(__bridge NSString*) iterator->getOSString()];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) infoGetKeys:(NSArray<NSString*>*) keys outInfo:(NSDictionary<NSString*, id>* _Nullable * _Nullable) outInfo
		error:(NSError**) error
{
	// Get info
	TVResult<TDictionary<CString> >	info =
											self.documentStorageServer->infoGet(
													CCoreFoundation::arrayOfStringsFrom((__bridge CFArrayRef) keys));
	if (info.hasError()) {
		// Error
		*error = [self errorFrom:info.getError()];

		return NO;
	}

	// Prepare out info
	*outInfo = (NSDictionary*) CFBridgingRelease(CCoreFoundation::createDictionaryRefFrom(*info));

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) infoSet:(NSDictionary<NSString*, id>*) info error:(NSError**) error
{
	// Set info
	OV<SError>	cppError =
						self.documentStorageServer->infoSet(
								CCoreFoundation::dictionaryOfStringsFrom((__bridge CFDictionaryRef) info));
	if (cppError.hasValue()) {
		// Error
		*error = [self errorFrom:*cppError];

		return NO;
	}

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) internalSet:(NSDictionary<NSString*, id>*) info error:(NSError**) error
{
	// Set info
	OV<SError>	cppError =
						self.documentStorageServer->internalSet(
								CCoreFoundation::dictionaryOfStringsFrom((__bridge CFDictionaryRef) info));
	if (cppError.hasValue()) {
		// Error
		*error = [self errorFrom:*cppError];

		return NO;
	}

	return YES;
}

// MARK: Private methods

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) composeResultsFrom:(const OV<SError>&) cppError error:(NSError**) error
{
	// Check error
	if (!cppError.hasValue())
		// Success
		return YES;
	else {
		// Error
		*error = [self errorFrom:*cppError];

		return NO;
	}
}

//----------------------------------------------------------------------------------------------------------------------
- (NSError*) errorFrom:(const SError&) error
{
	return [NSError errorWithDomain:(__bridge NSString*) error.getDomain().getOSString() code:error.getCode()
			userInfo:
					@{
						NSLocalizedDescriptionKey:
								(__bridge NSString*) error.getDefaultLocalizedDescription().getOSString(),
					 }];
}

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: Local proc definitions

//----------------------------------------------------------------------------------------------------------------------
bool sDocumentPropertyIsValue(const CString& documentType, const I<CMDSDocument>& document, const CDictionary& info,
		CMDSDocumentStorageServer* documentStorageServer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CString	property = info.getString(CString(OSSTR("property")));
	CString	value = info.getString(CString(OSSTR("value")));
	if (property.isEmpty() || value.isEmpty())
		// Missing info
		return false;

	// Get value
	OV<CString>	documentPropertyValue = documentStorageServer->documentStringValue(documentType, document, property);
	if (!documentPropertyValue.hasValue())
		// No value
		return false;

	return *documentPropertyValue == value;
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CString> sKeysForDocumentProperty(const CString& documentType, const I<CMDSDocument>& document,
		const CDictionary& info, CMDSDocumentStorageServer* documentStorageServer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CString	property = info.getString(CString(OSSTR("property")));
	if (property.isEmpty())
		// Missing info
		return TNArray<CString>();

	// Get value
	OV<CString>	documentPropertyValue = documentStorageServer->documentStringValue(documentType, document, property);
	if (!documentPropertyValue.hasValue())
		// No value
		return TNArray<CString>();

	return TNArray<CString>(*documentPropertyValue);
}

//----------------------------------------------------------------------------------------------------------------------
SValue sIntegerValueForProperty(const CString& documentType, const I<CMDSDocument>& document, const CString& property,
		CMDSDocumentStorageServer* documentStorageServer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SInt64>	value = documentStorageServer->documentIntegerValue(documentType, document, property);

	return value.hasValue() ? SValue(*value) : SValue(0);
}
