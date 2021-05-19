//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocument.h"

#include "CMDSDocumentStorage.h"
#include "TReferenceTracking.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentInternals

class CMDSDocumentInternals : public TReferenceCountable<CMDSDocumentInternals> {
	public:
		CMDSDocumentInternals(const CString& id, CMDSDocumentStorage& documentStorage) :
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
	mInternals = new CMDSDocumentInternals(id, documentStorage);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::CMDSDocument(const CMDSDocument& other)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = other.mInternals->addReference();
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::~CMDSDocument()
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->removeReference();
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSDocument::getID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mID;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSDocument::getCreationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.getCreationUniversalTime(*this);
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSDocument::getModificationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.getModificationUniversalTime(*this);
}

//----------------------------------------------------------------------------------------------------------------------
OI<TArray<CString> > CMDSDocument::getArrayOfStrings(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kArrayOfStrings));

	return value.hasInstance() ? OI<TArray<CString> >(value->getArrayOfStrings()) : OI<TArray<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const OR<TArray<CString> >& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.set(property, value.hasReference() ? OI<SValue>(*value) : OI<SValue>(), *this);
}

//----------------------------------------------------------------------------------------------------------------------
OV<bool> CMDSDocument::getBool(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kBool));

	return value.hasInstance() ? OV<bool>(value->getBool()) : OV<bool>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<bool> CMDSDocument::set(const CString& property, const OV<bool>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<bool>	previousValue = getBool(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OI<CData> CMDSDocument::getData(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.getData(property, *this);
}

//----------------------------------------------------------------------------------------------------------------------
OI<CData> CMDSDocument::set(const CString& property, const OR<CData>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OI<CData>	previousValue = getData(property);
	if ((value.hasReference() != previousValue.hasInstance()) ||
			(value.hasReference() && (*value != *previousValue)))
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasReference() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OI<CDictionary> CMDSDocument::getDictionary(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kDictionary));

	return value.hasInstance() ? OI<CDictionary>(value->getDictionary()) : OI<CDictionary>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const OR<CDictionary>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.set(property, value.hasReference() ? OI<SValue>(*value) : OI<SValue>(), *this);
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float64> CMDSDocument::getFloat64(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kFloat64));

	return value.hasInstance() ? OV<Float64>(value->getFloat64()) : OV<Float64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<Float64> CMDSDocument::set(const CString& property, const OV<Float64>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<Float64>	previousValue = getFloat64(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt32> CMDSDocument::getSInt32(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kSInt32));

	return value.hasInstance() ? OV<SInt32>(value->getSInt32()) : OV<SInt32>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt32> CMDSDocument::set(const CString& property, const OV<SInt32>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<SInt32>	previousValue = getSInt32(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSDocument::getSInt64(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kSInt64));

	return value.hasInstance() ? OV<SInt64>(value->getSInt64()) : OV<SInt64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSDocument::set(const CString& property, const OV<SInt64>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<SInt64>	previousValue = getSInt64(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OI<CString> CMDSDocument::getString(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kString));

	return value.hasInstance() ? OI<CString>(value->getString()) : OI<CString>();
}

//----------------------------------------------------------------------------------------------------------------------
OI<CString> CMDSDocument::set(const CString& property, const OR<CString>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OI<CString>	previousValue = getString(property);
	if ((value.hasReference() != previousValue.hasInstance()) ||
			(value.hasReference() && (*value != *previousValue)))
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasReference() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSDocument::getUInt32(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<SValue>	value = mInternals->mDocumentStorage.getValue(property, *this);
	AssertFailIf(value.hasInstance() && (value->getType() != SValue::kUInt32));

	return value.hasInstance() ? OV<UInt32>(value->getUInt32()) : OV<UInt32>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSDocument::set(const CString& property, const OV<UInt32>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UInt32>	previousValue = getUInt32(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSDocument::getUniversalTime(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentStorage.getUniversalTime(property, *this);
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSDocument::setUniversalTime(const CString& property, const OV<UniversalTime>& value) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if different
	OV<UniversalTime>	previousValue = getUniversalTime(property);
	if (value != previousValue)
		// Set value
		mInternals->mDocumentStorage.set(property, value.hasValue() ? OI<SValue>(*value) : OI<SValue>(), *this);

	return previousValue;
}

//----------------------------------------------------------------------------------------------------------------------
OI<CMDSDocument> CMDSDocument::getDocument(const CString& property, const CMDSDocument::Info& info) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<CString>	documentID = getString(property);
	if (documentID.hasInstance())
		// Have value
		return mInternals->mDocumentStorage.getDocument(*documentID, info);
	else
		// Don't have value
		return OI<CMDSDocument>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, OR<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	set(property, document.hasReference() ? OR<CString>((CString&) document->getID()) : OR<CString>());
}

//----------------------------------------------------------------------------------------------------------------------
OI<TArray<CMDSDocument> > CMDSDocument::getDocuments(const CString& property, const CMDSDocument::Info& info) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<TArray<CString> >	documentIDs = getArrayOfStrings(property);

	return documentIDs.hasInstance() ?
			OI<TArray<CMDSDocument> >(mInternals->mDocumentStorage.getDocuments(info, *documentIDs)) :
			OI<TArray<CMDSDocument> >();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const OR<TArray<CMDSDocument> >& documents) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for value
	if (documents.hasReference()) {
		// Collect document IDs
		TNArray<CString>	documentIDs;
		for (TIteratorD<CMDSDocument> iterator = documents->getIterator(); iterator.hasValue(); iterator.advance())
			// Add document ID
			documentIDs += iterator->getID();
		set(property, OR<TArray<CString> >(documentIDs));
	} else
		// No value
		set(property, OR<TArray<CString> >());
}

//----------------------------------------------------------------------------------------------------------------------
OI<TDictionary<CMDSDocument> > CMDSDocument::getDocumentMap(const CString& property, const CMDSDocument::Info& info)
		const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OI<CDictionary>	documentIDMap = getDictionary(property);

	// Check if have value
	if (documentIDMap.hasInstance()) {
		// Have value
		TCDictionary<CMDSDocument>	documentMap;
		for (TIteratorS<CDictionary::Item> iterator = documentIDMap->getIterator(); iterator.hasValue();
				iterator.advance()) {
			// Get document
			OI<CMDSDocument>	document = mInternals->mDocumentStorage.getDocument(iterator->mValue.getString(), info);
			AssertFailIf(!document.hasInstance());

			// Add document to map
			documentMap.set(iterator->mKey, *document);
		}

		return OI<TDictionary<CMDSDocument> >(documentMap);
	} else
		// Don't have value
		return OI<TDictionary<CMDSDocument> >();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::set(const CString& property, const OI<TDictionary<CMDSDocument> > documentMap) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if have value
	if (documentMap.hasInstance()) {
		// Have value
		TNDictionary<CString>	documentIDMap;
		for (TIteratorS<CDictionary::Item> iterator = documentMap->getIterator(); iterator.hasValue();
				iterator.advance())
			// Add document ID to map
			documentIDMap.set(iterator->mKey, ((CMDSDocument*) iterator->mValue.getOpaque())->getID());
		set(property, OR<CDictionary>(documentIDMap));
	} else
		// Don't have value
		set(property, OR<CDictionary>());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::remove(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Set value
	mInternals->mDocumentStorage.set(property, OI<SValue>(), *this);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocument::remove() const
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentStorage.remove(*this);
}
