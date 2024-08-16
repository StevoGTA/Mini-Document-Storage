//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument+WorkItem.cpp			©2024 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocument+WorkItem.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentLoadAttachmentDataWorkItem::Internals

class CMDSDocumentLoadAttachmentDataWorkItem::Internals {
	public:
		Internals(const I<CMDSDocument>& document, const CString& attachmentID) :
			mDocument(document), mAttachmentID(attachmentID)
			{}

		I<CMDSDocument>			mDocument;
		CString					mAttachmentID;

		OV<TVResult<CData> >	mData;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocumentLoadAttachmentDataWorkItem

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentLoadAttachmentDataWorkItem::CMDSDocumentLoadAttachmentDataWorkItem(const I<CMDSDocument>& document,
		const CString& attachmentID, const CString& id, const OV<CString>& reference, CompletedProc completedProc,
		CancelledProc cancelledProc, void* userData) :
		CWorkItem(id, reference, completedProc, cancelledProc, userData)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals(document, attachmentID);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentLoadAttachmentDataWorkItem::~CMDSDocumentLoadAttachmentDataWorkItem()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: CWorkItem methods

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentLoadAttachmentDataWorkItem::perform(const I<CWorkItem>& workItem)
//----------------------------------------------------------------------------------------------------------------------
{
	// Load data
	mInternals->mData.setValue(
			mInternals->mDocument->getAttachmentContent(
					CMDSDocument::AttachmentInfo(mInternals->mAttachmentID, 0, CDictionary::mEmpty)));
}

//----------------------------------------------------------------------------------------------------------------------
const TVResult<CData>& CMDSDocumentLoadAttachmentDataWorkItem::getData() const
//----------------------------------------------------------------------------------------------------------------------
{
	return *mInternals->mData;
}
