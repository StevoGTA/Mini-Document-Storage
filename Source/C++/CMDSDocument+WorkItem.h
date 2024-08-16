//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument+WorkItem.h			©2024 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"
#include "CWorkItem.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentLoadAttachmentDataWorkItem

class CMDSDocumentLoadAttachmentDataWorkItem : public CWorkItem {
	// Classes
	private:
		class Internals;

	// Methods
	public:
									// Lifecycle methods
									CMDSDocumentLoadAttachmentDataWorkItem(const I<CMDSDocument>& document,
											const CString& attachmentID, const CString& id = CUUID().getBase64String(),
											const OV<CString>& reference = OV<CString>(),
											CompletedProc completedProc = nil, CancelledProc cancelledProc = nil,
											void* userData = nil);
									~CMDSDocumentLoadAttachmentDataWorkItem();

									// CWorkItem methods
				void				perform(const I<CWorkItem>& workItem);

									// Instance methods
		const	TVResult<CData>&	getData() const;

	// Properties
	private:
		Internals*	mInternals;
};
