//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocument.h"

#include "CJSON.h"
#include "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocument::Internals

class CMDSDocument::Internals {
	public:
		Internals(const CString& id, CMDSDocumentStorage& documentStorage) :
			mID(id), mDocumentStorage(documentStorage)
			{}

		CString					mID;
		CMDSDocumentStorage&	mDocumentStorage;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocument

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::CMDSDocument(const CString& id, CMDSDocumentStorage& documentStorage)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals(id, documentStorage);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::~CMDSDocument()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSDocument::getID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mID;
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage& CMDSDocument::getDocumentStorage() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSDocument::getCreationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.documentCreationUniversalTime(makeI());
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSDocument::getModificationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.documentModificationUniversalTime(makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<TArray<CString> > CMDSDocument::getArrayOfStrings(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeArrayOfStrings));

	return value.hasValue() ? OV<TArray<CString> >(value->getArrayOfStrings()) : OV<TArray<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const TArray<CString>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<TArray<CDictionary> > CMDSDocument::getArrayOfDictionaries(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeArrayOfDictionaries));

	return value.hasValue() ? OV<TArray<CDictionary> >(value->getArrayOfDictionaries()) : OV<TArray<CDictionary> >();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const TArray<CDictionary>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<bool> CMDSDocument::getBool(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeBool));

	return value.hasValue() ? OV<bool>(value->getBool()) : OV<bool>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<bool> CMDSDocument::set(const CString& property, bool value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<bool>	previousValue = getBool(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSDocument::getData(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.documentData(property, makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSDocument::set(const CString& property, const CData& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<CData>	previousValue = getData(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CDictionary> CMDSDocument::getDictionary(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeDictionary));

	return value.hasValue() ? OV<CDictionary>(value->getDictionary()) : OV<CDictionary>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<CDictionary> CMDSDocument::set(const CString& property, const CDictionary& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<CDictionary>	previousValue = getDictionary(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float32> CMDSDocument::getFloat32(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeFloat32));

	return value.hasValue() ? OV<Float32>(value->getFloat32()) : OV<Float32>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float32> CMDSDocument::set(const CString& property, Float32 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<Float32>	previousValue = getFloat32(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float64> CMDSDocument::getFloat64(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeFloat64));

	return value.hasValue() ? OV<Float64>(value->getFloat64()) : OV<Float64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float64> CMDSDocument::set(const CString& property, Float64 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<Float64>	previousValue = getFloat64(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt32> CMDSDocument::getSInt32(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeSInt32));

	return value.hasValue() ? OV<SInt32>(value->getSInt32()) : OV<SInt32>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt32> CMDSDocument::set(const CString& property, SInt32 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<SInt32>	previousValue = getSInt32(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSDocument::getSInt64(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeSInt64));

	return value.hasValue() ? OV<SInt64>(value->getSInt64()) : OV<SInt64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSDocument::set(const CString& property, SInt64 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<SInt64>	previousValue = getSInt64(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSDocument::getString(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeString));

	return value.hasValue() ? OV<CString>(value->getString()) : OV<CString>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSDocument::set(const CString& property, const CString& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<CString>	previousValue = getString(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt8> CMDSDocument::getUInt8(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeUInt8));

	return value.hasValue() ? OV<UInt8>(value->getUInt8()) : OV<UInt8>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt8> CMDSDocument::set(const CString& property, UInt8 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt8>	previousValue = getUInt8(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt8> CMDSDocument::set(const CString& property, const OV<UInt8>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt8>	previousValue = getUInt8(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.documentSet(property, value.hasValue() ? OV<SValue>(*value) : OV<SValue>(),
				makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt16> CMDSDocument::getUInt16(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeUInt16));

	return value.hasValue() ? OV<UInt16>(value->getUInt16()) : OV<UInt16>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt16> CMDSDocument::set(const CString& property, UInt16 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt16>	previousValue = getUInt16(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSDocument::getUInt32(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeUInt32));

	return value.hasValue() ? OV<UInt32>(value->getUInt32()) : OV<UInt32>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSDocument::set(const CString& property, UInt32 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt32>	previousValue = getUInt32(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt64> CMDSDocument::getUInt64(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = mInternals->mDocumentStorage.documentValue(property, makeI());
	AssertFailIf(value.hasValue() && (value->getType() != SValue::kTypeUInt64));

	return value.hasValue() ? OV<UInt64>(value->getUInt64()) : OV<UInt64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt64> CMDSDocument::set(const CString& property, UInt64 value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt64>	previousValue = getUInt64(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI());

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSDocument::getUniversalTime(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.documentUniversalTime(property, makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSDocument::setUniversalTime(const CString& property, UniversalTime value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UniversalTime>	previousValue = getUniversalTime(property);
	if (!previousValue.hasValue() || (value != *previousValue))
		// Set value
		mInternals->mDocumentStorage.documentSet(property, OV<SValue>(value), makeI(),
				CMDSDocumentStorage::kSetValueKindUniversalTime);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const TArray<CMDSDocument>& documents) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect document IDs
	TNArray<CString>	documentIDs;
	for (TIteratorD<CMDSDocument> iterator = documents.getIterator(); iterator.hasValue(); iterator.advance())
		// Add document ID
		documentIDs += iterator->getID();
	set(property, documentIDs);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::remove(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.documentSet(property, OV<SValue>(), makeI());
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument::AttachmentInfo> CMDSDocument::getAttachmentInfos(const CString& type) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get attachment info map
	TVResult<CMDSDocument::AttachmentInfoByID>	attachmentInfoByID =
														getDocumentStorage().documentAttachmentInfoByID(
																getDocumentType(), getID());

	// Filter by type
	TSet<CString>			attachmentIDs = attachmentInfoByID->getKeys();
	TNArray<AttachmentInfo>	attachmentInfos;
	for (TIteratorS<CString> iterator = attachmentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Get Attachment Info
		AttachmentInfo&	attachmentInfo = *(attachmentInfoByID->get(*iterator));

		// Check type
		if (attachmentInfo.getType() == type)
			// Match!
			attachmentInfos += attachmentInfo;
	}

	return attachmentInfos;
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CData> CMDSDocument::getAttachmentContent(const AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Return content
	return getDocumentStorage().documentAttachmentContent(getDocumentType(), getID(), attachmentInfo.getID());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CString> CMDSDocument::getAttachmentContentAsString(const AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get attachment content
	TVResult<CData>	data =
							getDocumentStorage().documentAttachmentContent(getDocumentType(), getID(),
									attachmentInfo.getID());
	ReturnValueIfResultError(data, TVResult<CString>(data.getError()));

	return CString(*data);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CDictionary> CMDSDocument::getAttachmentContentAsDictionary(const AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get attachment content
	TVResult<CData>	data =
							getDocumentStorage().documentAttachmentContent(getDocumentType(), getID(),
									attachmentInfo.getID());
	ReturnValueIfResultError(data, TVResult<CDictionary>(data.getError()));

	return *CJSON::dictionaryFrom(*data);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CDictionary> > CMDSDocument::getAttachmentContentAsArrayOfDictionaries(
		const AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get attachment content
	TVResult<CData>	data =
							getDocumentStorage().documentAttachmentContent(getDocumentType(), getID(),
									attachmentInfo.getID());
	ReturnValueIfResultError(data, TVResult<TArray<CDictionary> >(data.getError()));

	return *CJSON::arrayOfDictionariesFrom(*data);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfo CMDSDocument::addAttachment(const CString& type, const CDictionary& info,
		const CData& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Add attachment
	return *getDocumentStorage().documentAttachmentAdd(getDocumentType(), getID(), type, info, content);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfo CMDSDocument::addAttachment(const CString& type, const CDictionary& info,
		const CDictionary& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Add attachment
	return *getDocumentStorage().documentAttachmentAdd(getDocumentType(), getID(), type, info,
			*CJSON::dataFrom(content));
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfo CMDSDocument::addAttachment(const CString& type, const CDictionary& info,
		const TArray<CDictionary>& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Add attachment
	return *getDocumentStorage().documentAttachmentAdd(getDocumentType(), getID(), type, info,
			*CJSON::dataFrom(content));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::updateAttachment(const AttachmentInfo& attachmentInfo, const CDictionary& updatedInfo,
		const CData& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Update attachment
	getDocumentStorage().documentAttachmentUpdate(getDocumentType(), getID(), attachmentInfo.getID(), updatedInfo,
			updatedContent);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::updateAttachment(const AttachmentInfo& attachmentInfo, const CDictionary& updatedInfo,
		const CDictionary& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Update attachment
	getDocumentStorage().documentAttachmentUpdate(getDocumentType(), getID(), attachmentInfo.getID(), updatedInfo,
			*CJSON::dataFrom(updatedContent));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::updateAttachment(const AttachmentInfo& attachmentInfo, const CDictionary& updatedInfo,
		const TArray<CDictionary>& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Update attachment
	getDocumentStorage().documentAttachmentUpdate(getDocumentType(), getID(), attachmentInfo.getID(), updatedInfo,
			*CJSON::dataFrom(updatedContent));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::removeAttachment(const AttachmentInfo& attachmentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove attachment
	getDocumentStorage().documentAttachmentRemove(getDocumentType(), getID(), attachmentInfo.getID());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::remove() const
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentStorage.documentRemove(makeI());
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSDocument::associationRegisterTo(const Info& info) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.associationRegister(getInfo(), info);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSDocument::associationUpdateAddTo(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.associationUpdateAdd(makeI(), document);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSDocument::associationUpdateRemoveTo(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.associationUpdateRemove(makeI(), document);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<I<CMDSDocument> > > CMDSDocument::associationGetDocumentsFrom(const CMDSDocument::Info& toInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.associationGetDocumentsFrom(makeI(), toInfo);
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - SMDSValueType

const	CString	SMDSValueType::mInteger(OSSTR("integer"));
