//----------------------------------------------------------------------------------------------------------------------
//	CMDSAssociation.cpp			©2026 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSAssociation.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSAssociation::Item

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSAssociation::Item::Item(const CDictionary& storageInfo) :
		mFromDocumentID(storageInfo.getString(CString(OSSTR("fromDocumentID")))),
		mToDocumentID(storageInfo.getString(CString(OSSTR("toDocumentID"))))
//----------------------------------------------------------------------------------------------------------------------
{
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
CDictionary CMDSAssociation::Item::getStorageInfo() const
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose Storage info
	CDictionary	storageInfo;
	storageInfo.set(CString(OSSTR("fromDocumentID")), mFromDocumentID);
	storageInfo.set(CString(OSSTR("toDocumentID")), mToDocumentID);

	return storageInfo;
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSAssociation

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSAssociation::CMDSAssociation(const CDictionary& storageInfo) :
		mName(storageInfo.getString(CString(OSSTR("name")))),
		mFromDocumentType(storageInfo.getString(CString(OSSTR("fromDocumentType")))),
		mToDocumentType(storageInfo.getString(CString(OSSTR("toDocumentType"))))
//----------------------------------------------------------------------------------------------------------------------
{
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
CDictionary CMDSAssociation::getStorageInfo() const
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose Storage info
	CDictionary	storageInfo;
	storageInfo.set(CString(OSSTR("name")), mName);
	storageInfo.set(CString(OSSTR("fromDocumentType")), mFromDocumentType);
	storageInfo.set(CString(OSSTR("toDocumentType")), mToDocumentType);

	return storageInfo;
}
