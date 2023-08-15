//
//  MDSDocumentStorageObjC.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/24/23.
//

#import "MDSDocumentStorageObjC.h"

#import "CCoreFoundation.h"
#import "CMDSDocumentStorage.h"

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

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSAssociationUpdate

@implementation MDSAssociationUpdate

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
		self.documentID = (NSString*) CFBridgingRelease(documentOverviewInfo.getDocumentID().getOSString());
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
// MARK: - MDSDocumentCreateInfo

@implementation MDSDocumentCreateInfo

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

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CGenericDocument

class CGenericDocument : public CMDSDocument {
	// InfoForNew
	public:
		class InfoForNew : public CMDSDocument::InfoForNew {
			public:
										// Lifecycle methods
										InfoForNew() : CMDSDocument::InfoForNew() {}

										// Instance mehtods
				const	CString&		getDocumentType() const
											{ return mDocumentType; }
						I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage) const
											{ return I<CMDSDocument>(new CGenericDocument(id, documentStorage)); }
		};

	// Methods
	public:
										// CMDSDocument methods
				const	Info&			getInfo() const
											{ return mInfo; }

										// Class methods
		static			I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage)
											{ return I<CMDSDocument>(new CGenericDocument(id, documentStorage)); }

	private:
										// Lifecycle methods
										CGenericDocument(const CString& id, CMDSDocumentStorage& documentStorage) :
											CMDSDocument(id, documentStorage)
											{}

	// Properties
	private:
		static	CString		mDocumentType;
		static	Info		mInfo;
};

CString				CGenericDocument::mDocumentType(OSSTR("generic"));
CMDSDocument::Info	CGenericDocument::mInfo(mDocumentType, CGenericDocument::create);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC ()

@property (nonatomic, assign)	CMDSDocumentStorage*	documentStorage;

@end

@implementation MDSDocumentStorageObjC

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (void) dealloc
{
	// Cleanup
	Delete(self.documentStorage);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error
{
	// Register association
	OV<SError>	sError =
						self.documentStorage->associationRegister(CString((__bridge CFStringRef) name),
								CString((__bridge CFStringRef) fromDocumentType),
								CString((__bridge CFStringRef) toDocumentType));

	return [self composeResultsFrom:sError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationGetNamed:(NSString*) name
		associationItems:(MDSAssociationItemArray* _Nullable * _Nullable) associationItems error:(NSError**) error
{
	// Get all associations
	TVResult<TArray<CMDSAssociation::Item> >	associationItemsResult =
														self.documentStorage->associationGet(
																CString((__bridge CFStringRef) name));
	if (associationItemsResult.hasError()) {
		// Error
		*error = [self errorFrom:associationItemsResult.getError()];

		return NO;
	}

	// Prepare results
	*associationItems = [[NSMutableArray alloc] init];
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItemsResult.getValue().getIterator();
			iterator.hasValue(); iterator.advance())
		// Add item
		[(NSMutableArray*) *associationItems
				addObject:
						[[MDSAssociationItem alloc]
								initWithFromDocumentID:(__bridge NSString*) iterator->getFromDocumentID().getOSString()
										toDocumentID:(__bridge NSString*) iterator->getToDocumentID().getOSString()]];

	return YES;
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationUpdateNamed:(NSString*) name associationUpdates:(MDSAssociationUpdateArray*) associationUpdates
		error:(NSError**) error
{
	// Setup
	TNArray<CMDSAssociation::Update>	cppAssociationUpdates;
	for (MDSAssociationUpdate* associationUpdate in associationUpdates) {
		// Get info
		switch (associationUpdate.action) {
			case kMDSAssociationUpdateActionAdd:
				// Add
				cppAssociationUpdates +=
						CMDSAssociation::Update::add(
								CString((__bridge CFStringRef) associationUpdate.fromDocumentID),
								CString((__bridge CFStringRef) associationUpdate.toDocumentID));
				break;

			case kMDSAssociationUpdateActionRemove:
				// Remove
				cppAssociationUpdates +=
						CMDSAssociation::Update::remove(
								CString((__bridge CFStringRef) associationUpdate.fromDocumentID),
								CString((__bridge CFStringRef) associationUpdate.toDocumentID));
				break;
		}
	}

	// Update association
	OV<SError>	sError =
						self.documentStorage->associationUpdate(CString((__bridge CFStringRef) name),
								cppAssociationUpdates);

	return [self composeResultsFrom:sError error:error];
}

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) documentCreateDocumentType:(NSString*) documentType
		documentCreateInfos:(NSArray<MDSDocumentCreateInfo*>*) documentCreateInfos
		documentOverviewInfos:(NSArray<MDSDocumentOverviewInfo*>* _Nullable * _Nonnull) documentOverviewInfos
		error:(NSError**) error
{
	// Setup
	TNArray<CMDSDocument::CreateInfo>	cppDocumentCreateInfos;
	for (MDSDocumentCreateInfo* documentCreateInfo in documentCreateInfos) {
		// Get info
		NSString*	_Nullable	documentID = documentCreateInfo.documentID;
		NSDate*		_Nullable	creationDate = documentCreateInfo.creationDate;
		NSDate*		_Nullable	modificationDate = documentCreateInfo.modificationDate;

		// Add
		cppDocumentCreateInfos +=
				CMDSDocument::CreateInfo(
						(documentID != nil) ? OV<CString>(CString((__bridge CFStringRef) documentID)) : OV<CString>(),
						(creationDate != nil) ?
								OV<UniversalTime>(creationDate.timeIntervalSinceReferenceDate) :
								OV<UniversalTime>(),
						(modificationDate != nil) ?
								OV<UniversalTime>(modificationDate.timeIntervalSinceReferenceDate) :
								OV<UniversalTime>(),
						CCoreFoundation::dictionaryFrom((__bridge CFDictionaryRef) documentCreateInfo.propertyMap));
	}

	// Create documents
	TVResult<TArray<CMDSDocument::CreateResultInfo> >	result =
																self.documentStorage->documentCreate(
																		CString((__bridge CFStringRef) documentType),
																		cppDocumentCreateInfos,
																		CGenericDocument::InfoForNew());

	// Handle results
	if (result.hasValue()) {
		// Success
		*documentOverviewInfos = [[NSMutableArray<MDSDocumentOverviewInfo*> alloc] init];
		for (TIteratorD<CMDSDocument::CreateResultInfo> iterator = result.getValue().getIterator(); iterator.hasValue();
				iterator.advance())
			// Add Overview Info
			[(NSMutableArray<MDSDocumentOverviewInfo*>*) *documentOverviewInfos
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

// MARK: Private methods

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) composeResultsFrom:(const OV<SError>&) sError error:(NSError**) error
{
	// Check error
	if (!sError.hasValue())
		// Success
		return YES;
	else {
		// Error
		*error = [self errorFrom:*sError];

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
