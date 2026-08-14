//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentNotifications.cpp			©2026 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocument.h"

#include "CMDSDocumentStorage.h"
#include "CNotificationCenter.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local procs

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentCreated(const I<CMDSDocument>& document, CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Post to the notification center
	notificationCenter->post(CMDSDocument::mCreatedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document));
}

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentUpdated(const I<CMDSDocument>& document, const TSet<CString>& updatedProperties,
		const TSet<CString>& removedProperties, const TSet<CString>& changedProperties,
		CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose info
	CDictionary	info;
	info.set(CString(OSSTR("updatedProperties")), TNSet<CString>(updatedProperties).getArray());
	info.set(CString(OSSTR("removedProperties")), TNSet<CString>(removedProperties).getArray());
	info.set(CString(OSSTR("changedProperties")), TNSet<CString>(changedProperties).getArray());

	// Post to the notification center
	notificationCenter->post(CMDSDocument::mUpdatedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document), info);
}

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentRemoved(const I<CMDSDocument>& document, CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Post to the notification center
	notificationCenter->post(CMDSDocument::mRemovedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document));
}

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentAttachmentCreated(const I<CMDSDocument>& document, const CString& attachmentID,
		const CMDSDocument::AttachmentInfo& attachmentInfo, CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose info
	CDictionary	info;
	info.set(CString(OSSTR("attachmentID")), attachmentID);
	info.set(CString(OSSTR("attachmentInfo")), attachmentInfo.getStorageInfo());

	// Post to the notification center
	notificationCenter->post(CMDSDocument::mAttachmentCreatedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document), info);
}

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentAttachmentUpdated(const I<CMDSDocument>& document, const CString& attachmentID,
		const CMDSDocument::AttachmentInfo& attachmentInfo, CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose info
	CDictionary	info;
	info.set(CString(OSSTR("attachmentID")), attachmentID);
	info.set(CString(OSSTR("attachmentInfo")), attachmentInfo.getStorageInfo());

	// Post to the notification center
	notificationCenter->post(CMDSDocument::mAttachmentUpdatedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document), info);
}

//----------------------------------------------------------------------------------------------------------------------
static void sPostDocumentAttachmentRemoved(const I<CMDSDocument>& document, const CString& attachmentID,
		CNotificationCenter* notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose info
	CDictionary	info;
	info.set(CString(OSSTR("attachmentID")), attachmentID);

	// Post to the notification center
	notificationCenter->post(CMDSDocument::mAttachmentRemovedNotificationName,
			CNotificationCenter::VSender<I<CMDSDocument> >(document), info);
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocument

// MARK: Notification names

const	CString CMDSDocument::mCreatedNotificationName(OSSTR("MDSDocument.created"));
const	CString CMDSDocument::mUpdatedNotificationName(OSSTR("MDSDocument.updated"));
const	CString CMDSDocument::mRemovedNotificationName(OSSTR("MDSDocument.removed"));
const	CString CMDSDocument::mAttachmentCreatedNotificationName(OSSTR("MDSDocument.attachmentCreated"));
const	CString CMDSDocument::mAttachmentUpdatedNotificationName(OSSTR("MDSDocument.attachmentUpdated"));
const	CString CMDSDocument::mAttachmentRemovedNotificationName(OSSTR("MDSDocument.attachmentRemoved"));

// MARK: Class methods

//----------------------------------------------------------------------------------------------------------------------
const I<CMDSDocument>& CMDSDocument::notificationGetDocument(const OR<CNotificationCenter::Sender>& sender)
//----------------------------------------------------------------------------------------------------------------------
{
	return *((const CNotificationCenter::VSender<I<CMDSDocument> >&) *sender);
}

//----------------------------------------------------------------------------------------------------------------------
TSet<CString> CMDSDocument::notificationGetUpdatedProperties(const CDictionary& info)
//----------------------------------------------------------------------------------------------------------------------
{
	return TNSet<CString>(info.getArrayOfStrings(CString(OSSTR("updatedProperties"))));
}

//----------------------------------------------------------------------------------------------------------------------
TSet<CString> CMDSDocument::notificationGetRemovedProperties(const CDictionary& info)
//----------------------------------------------------------------------------------------------------------------------
{
	return TNSet<CString>(info.getArrayOfStrings(CString(OSSTR("removedProperties"))));
}

//----------------------------------------------------------------------------------------------------------------------
TSet<CString> CMDSDocument::notificationGetChangedProperties(const CDictionary& info)
//----------------------------------------------------------------------------------------------------------------------
{
	return TNSet<CString>(info.getArrayOfStrings(CString(OSSTR("changedProperties"))));
}

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSDocument::notificationGetAttachmentID(const CDictionary& info)
//----------------------------------------------------------------------------------------------------------------------
{
	return info.getString(CString(OSSTR("attachmentID")));
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfo CMDSDocument::notificationGetAttachmentInfo(const CDictionary& info)
//----------------------------------------------------------------------------------------------------------------------
{
	return CMDSDocument::AttachmentInfo(info.getDictionary(CString(OSSTR("attachmentInfo"))));
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocumentStorage

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentCreatedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentCreatedCallback(documentInfo,
			CMDSDocument::CreatedCallback((CMDSDocument::CreatedCallback::Proc) sPostDocumentCreated,
					&notificationCenter));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentUpdatedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentUpdatedCallback(documentInfo,
			CMDSDocument::UpdatedCallback((CMDSDocument::UpdatedCallback::Proc) sPostDocumentUpdated,
					&notificationCenter));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentRemovedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentRemovedCallback(documentInfo,
			CMDSDocument::RemovedCallback((CMDSDocument::RemovedCallback::Proc) sPostDocumentRemoved,
					&notificationCenter));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentCreatedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentAttachmentCreatedCallback(documentInfo,
			CMDSDocument::AttachmentCreatedCallback(
					(CMDSDocument::AttachmentCreatedCallback::Proc) sPostDocumentAttachmentCreated,
					&notificationCenter));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentUpdatedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentAttachmentUpdatedCallback(documentInfo,
			CMDSDocument::AttachmentUpdatedCallback(
					(CMDSDocument::AttachmentUpdatedCallback::Proc) sPostDocumentAttachmentUpdated,
					&notificationCenter));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentRemovedNotification(const CMDSDocument::Info& documentInfo,
		CNotificationCenter& notificationCenter)
//----------------------------------------------------------------------------------------------------------------------
{
	registerDocumentAttachmentRemovedCallback(documentInfo,
			CMDSDocument::AttachmentRemovedCallback(
					(CMDSDocument::AttachmentRemovedCallback::Proc) sPostDocumentAttachmentRemoved,
					&notificationCenter));
}
