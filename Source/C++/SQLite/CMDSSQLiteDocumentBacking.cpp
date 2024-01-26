//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDocumentBacking.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLiteDocumentBacking.h"

#include "CMDSSQLiteDatabaseManager.h"
#include "ConcurrencyPrimitives.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types

typedef	CMDSSQLiteDatabaseManager::DocumentCreateInfo			DocumentCreateInfo;
typedef	CMDSSQLiteDatabaseManager::DocumentUpdateInfo			DocumentUpdateInfo;
typedef	CMDSSQLiteDatabaseManager::DocumentAttachmentInfo		DocumentAttachmentInfo;
typedef	CMDSSQLiteDatabaseManager::DocumentAttachmentRemoveInfo	DocumentAttachmentRemoveInfo;

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDocumentBacking::Internals

class CMDSSQLiteDocumentBacking::Internals {
	public:
		Internals(SInt64 id, const CString& documentID, UInt32 revision, bool active,
				UniversalTime creationUniversalTime, UniversalTime modificationUniversalTime,
				const CDictionary& propertyMap, const CMDSDocument::AttachmentInfoMap& documentAttachmentInfoMap) :
			mID(id), mDocumentID(documentID), mCreationUniversalTime(creationUniversalTime),
					mRevision(revision), mActive(active), mModificationUniversalTime(modificationUniversalTime),
					mPropertyMap(propertyMap), mDocumentAttachmentInfoMap(documentAttachmentInfoMap)
			{}

		SInt64										mID;
		CString										mDocumentID;
		UniversalTime								mCreationUniversalTime;

		UInt32										mRevision;
		bool										mActive;
		UniversalTime								mModificationUniversalTime;
		CDictionary									mPropertyMap;
		TNDictionary<CMDSDocument::AttachmentInfo>	mDocumentAttachmentInfoMap;

		CReadPreferringLock							mPropertiesLock;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDocumentBacking

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDocumentBacking::CMDSSQLiteDocumentBacking(SInt64 id, const CString& documentID, UInt32 revision,
		bool active, UniversalTime creationUniversalTime, UniversalTime modificationUniversalTime,
		const CDictionary& propertyMap, const CMDSDocument::AttachmentInfoMap& documentAttachmentInfoMap)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals =
			new Internals(id, documentID, revision, active, creationUniversalTime, modificationUniversalTime,
					propertyMap, documentAttachmentInfoMap);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDocumentBacking::CMDSSQLiteDocumentBacking(const CString& documentType,
		const CString& documentID, const OV<UniversalTime>& creationUniversalTime,
		const OV<UniversalTime>& modificationUniversalTime, const CDictionary& propertyMap,
		CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentCreateInfo	documentCreateInfo =
								databaseManager.documentCreate(documentType, documentID, creationUniversalTime,
										modificationUniversalTime, propertyMap);

	mInternals =
			new Internals(documentCreateInfo.getID(), documentID, documentCreateInfo.getRevision(), true,
					documentCreateInfo.getCreationUniversalTime(), documentCreateInfo.getModificationUniversalTime(),
					propertyMap, TNDictionary<CMDSDocument::AttachmentInfo>());
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDocumentBacking::~CMDSSQLiteDocumentBacking()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
SInt64 CMDSSQLiteDocumentBacking::getID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mID;
}

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSSQLiteDocumentBacking::getDocumentID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentID;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLiteDocumentBacking::getCreationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mCreationUniversalTime;
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDocumentBacking::getRevision() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mRevision;
}

//----------------------------------------------------------------------------------------------------------------------
bool CMDSSQLiteDocumentBacking::getActive() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mActive;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLiteDocumentBacking::getModificationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mModificationUniversalTime;
}

//----------------------------------------------------------------------------------------------------------------------
CDictionary CMDSSQLiteDocumentBacking::getPropertyMap() const
//----------------------------------------------------------------------------------------------------------------------
{
	// Copy
	mInternals->mPropertiesLock.lockForReading();
	CDictionary	propertyMap = mInternals->mPropertyMap;
	mInternals->mPropertiesLock.unlockForReading();

	return propertyMap;
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfoMap CMDSSQLiteDocumentBacking::getDocumentAttachmentInfoMap() const
//----------------------------------------------------------------------------------------------------------------------
{
	// Copy
	mInternals->mPropertiesLock.lockForReading();
	CMDSDocument::AttachmentInfoMap	documentAttachmentInfoMap = mInternals->mDocumentAttachmentInfoMap;
	mInternals->mPropertiesLock.unlockForReading();

	return documentAttachmentInfoMap;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSSQLiteDocumentBacking::getValue(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve value
	mInternals->mPropertiesLock.lockForReading();
	OV<SValue>	value =
						mInternals->mPropertyMap.contains(property) ?
								OV<SValue>(mInternals->mPropertyMap.getValue(property)) : OV<SValue>();
	mInternals->mPropertiesLock.unlockForReading();

	return value;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDocumentBacking::set(const CString& property, const OV<SValue>& value, const CString& documentType,
		CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Update
	if (value.hasValue()) {
		// Set
		CDictionary	updatedPropertyMap;
		updatedPropertyMap.set(property, *value);

		update(documentType, OV<CDictionary>(updatedPropertyMap), OV<const TSet<CString> >(), databaseManager);
	} else
		// Remove
		update(documentType, OV<CDictionary>(), OV<const TSet<CString> >(TNSet<CString>(property)), databaseManager);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDocumentBacking::update(const CString& documentType, const OV<CDictionary>& updatedPropertyMap,
		const OV<const TSet<CString> >& removedProperties, CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mPropertiesLock.lockForWriting();

	// Update
	if (updatedPropertyMap.hasValue()) mInternals->mPropertyMap += *updatedPropertyMap;
	if (removedProperties.hasValue()) mInternals->mPropertyMap.remove(*removedProperties);

	// Update persistent storage
	DocumentUpdateInfo	documentUpdateInfo =
								databaseManager.documentUpdate(documentType, mInternals->mID, mInternals->mPropertyMap);

	// Update properties
	mInternals->mRevision = documentUpdateInfo.getRevision();
	mInternals->mModificationUniversalTime = documentUpdateInfo.getModificationUniversalTime();

	// Done
	mInternals->mPropertiesLock.unlockForWriting();
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfo CMDSSQLiteDocumentBacking::attachmentAdd(const CString& documentType,
		const CDictionary& info, const CData& content, CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mPropertiesLock.lockForWriting();

	// Update persistent storage
	DocumentAttachmentInfo	documentAttachmentInfo =
									databaseManager.documentAttachmentAdd(documentType, mInternals->mID, info, content);

	// Update
	mInternals->mRevision = documentAttachmentInfo.getRevision();
	mInternals->mModificationUniversalTime = documentAttachmentInfo.getModificationUniversalTime();
	mInternals->mDocumentAttachmentInfoMap.set(documentAttachmentInfo.getDocumentAttachmentInfo().getID(),
			documentAttachmentInfo.getDocumentAttachmentInfo());

	// Done
	mInternals->mPropertiesLock.unlockForWriting();

	return documentAttachmentInfo.getDocumentAttachmentInfo();
}

//----------------------------------------------------------------------------------------------------------------------
CData CMDSSQLiteDocumentBacking::attachmentContent(const CString& documentType, const CString& attachmentID,
		CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return content
	return databaseManager.documentAttachmentContent(documentType, mInternals->mID, attachmentID);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDocumentBacking::attachmentUpdate(const CString& documentType, const CString& attachmentID,
		const CDictionary& updatedInfo, const CData& updatedContent, CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mPropertiesLock.lockForWriting();

	// Update persistent storage
	DocumentAttachmentInfo	documentAttachmentInfo =
									databaseManager.documentAttachmentUpdate(documentType, mInternals->mID,
											attachmentID, updatedInfo, updatedContent);

	// Update
	mInternals->mRevision = documentAttachmentInfo.getRevision();
	mInternals->mModificationUniversalTime = documentAttachmentInfo.getModificationUniversalTime();
	mInternals->mDocumentAttachmentInfoMap.set(attachmentID, documentAttachmentInfo.getDocumentAttachmentInfo());

	// Done
	mInternals->mPropertiesLock.unlockForWriting();

	return documentAttachmentInfo.getRevision();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDocumentBacking::attachmentRemove(const CString& documentType, const CString& attachmentID,
		CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mPropertiesLock.lockForWriting();

	// Update persistent storage
	DocumentAttachmentRemoveInfo	documentAttachmentRemoveInfo =
											databaseManager.documentAttachmentRemove(documentType, mInternals->mID,
												attachmentID);

	// Update
	mInternals->mRevision = documentAttachmentRemoveInfo.getRevision();
	mInternals->mModificationUniversalTime = documentAttachmentRemoveInfo.getModificationUniversalTime();
	mInternals->mDocumentAttachmentInfoMap.remove(attachmentID);

	// Done
	mInternals->mPropertiesLock.unlockForWriting();
}
