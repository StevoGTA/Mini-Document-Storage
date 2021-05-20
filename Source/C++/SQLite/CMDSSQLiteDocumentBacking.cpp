//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDocumentBacking.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLiteDocumentBacking.h"

#include "ConcurrencyPrimitives.h"
#include "CMDSSQLiteDatabaseManager.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSSQLiteDocumentBackingInternals

class CMDSSQLiteDocumentBackingInternals {
	public:
		CMDSSQLiteDocumentBackingInternals(SInt64 id, UInt32 revision, UniversalTime creationUniversalTime,
				UniversalTime modificationUniversalTime, const CDictionary& propertyMap, bool active) :
			mID(id), mRevision(revision), mCreationUniversalTime(creationUniversalTime),
					mModificationUniversalTime(modificationUniversalTime), mPropertyMap(propertyMap), mActive(active)
			{}

		SInt64				mID;
		UInt32				mRevision;
		UniversalTime		mCreationUniversalTime;
		UniversalTime		mModificationUniversalTime;
		CDictionary			mPropertyMap;
		bool				mActive;
		CReadPreferringLock	mPropertiesLock;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDocumentBacking

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDocumentBacking::CMDSSQLiteDocumentBacking(SInt64 id, UInt32 revision, UniversalTime creationUniversalTime,
		UniversalTime modificationUniversalTime, const CDictionary& propertyMap, bool active)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals =
			new CMDSSQLiteDocumentBackingInternals(id, revision, creationUniversalTime, modificationUniversalTime,
					propertyMap, active);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDocumentBacking::CMDSSQLiteDocumentBacking(const CString& documentType, const CString& documentID,
		UniversalTime creationUniversalTime, UniversalTime modificationUniversalTime, const CDictionary& propertyMap,
		CMDSSQLiteDatabaseManager& databaseManager)
//----------------------------------------------------------------------------------------------------------------------
{
	// Store
	CMDSSQLiteDatabaseManager::NewDocumentInfo	newDocumentInfo =
														databaseManager.newDocument(documentType, documentID,
																creationUniversalTime, modificationUniversalTime,
																propertyMap);

	// Setup
	mInternals =
			new CMDSSQLiteDocumentBackingInternals(newDocumentInfo.mID, newDocumentInfo.mRevision,
					newDocumentInfo.mCreationUniversalTime, newDocumentInfo.mModificationUniversalTime, propertyMap,
					true);
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
UInt32 CMDSSQLiteDocumentBacking::getRevision() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mRevision;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLiteDocumentBacking::getCreationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mCreationUniversalTime;
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLiteDocumentBacking::getModificationUniversalTime() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mModificationUniversalTime;
}

//----------------------------------------------------------------------------------------------------------------------
OI<SValue> CMDSSQLiteDocumentBacking::getValue(const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve value
	mInternals->mPropertiesLock.lockForReading();
	OI<SValue>	value =
						mInternals->mPropertyMap.contains(property) ?
								OI<SValue>(mInternals->mPropertyMap.getValue(property)) : OI<SValue>();
	mInternals->mPropertiesLock.unlockForReading();

	return value;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDocumentBacking::set(const CString& property, const OI<SValue>& value, const CString& documentType,
		CMDSSQLiteDatabaseManager& databaseManager, bool commitChange)
//----------------------------------------------------------------------------------------------------------------------
{
	// Update
	if (value.hasInstance()) {
		// Set
		CDictionary	updatedPropertyMap;
		updatedPropertyMap.set(property, *value);

		update(documentType, updatedPropertyMap, TSet<CString>(), databaseManager, commitChange);
	} else
		// Remove
		update(documentType, CDictionary(), TSet<CString>(property), databaseManager, commitChange);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDocumentBacking::update(const CString& documentType, const CDictionary& updatedPropertyMap,
		const TSet<CString>& removedProperties, CMDSSQLiteDatabaseManager& databaseManager, bool commitChange)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mPropertiesLock.lockForWriting();

	// Update
	mInternals->mPropertyMap += updatedPropertyMap;
	mInternals->mPropertyMap.remove(removedProperties);

	// Check if committing change
	if (commitChange) {
		// Get info
		CMDSSQLiteDatabaseManager::UpdateInfo	updateInfo =
														databaseManager.updateDocument(documentType, mInternals->mID,
																mInternals->mPropertyMap);

		// Store
		mInternals->mRevision = updateInfo.mRevision;
		mInternals->mModificationUniversalTime = updateInfo.mModificationUniversalTime;
	}

	// Done
	mInternals->mPropertiesLock.unlockForWriting();
}
