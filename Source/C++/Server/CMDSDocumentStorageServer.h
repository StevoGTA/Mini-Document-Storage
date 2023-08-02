//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorageServer.h			©2023	Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentStorageServer

class CMDSDocumentStorageServer : public CMDSDocumentStorage {
	// DocumentRevisionInfosWithCount
	public:
		struct DocumentRevisionInfosWithTotalCount {
			// Methods
															// Lifecycle methods
															DocumentRevisionInfosWithTotalCount(UInt32 totalCount,
																	const TArray<CMDSDocument::RevisionInfo>&
																			documentRevisionInfos) :
																mTotalCount(totalCount),
																		mDocumentRevisionInfos(documentRevisionInfos)
																{}
															DocumentRevisionInfosWithTotalCount(
																	const DocumentRevisionInfosWithTotalCount& other) :
																mTotalCount(other.mTotalCount),
																		mDocumentRevisionInfos(
																				other.mDocumentRevisionInfos)
																{}

															// Instance methods
						UInt32								getTotalCount() const
																{ return mTotalCount; }
				const	TArray<CMDSDocument::RevisionInfo>&	getDocumentRevisionInfos() const
																{ return mDocumentRevisionInfos; }
			// Properties
			private:
				UInt32								mTotalCount;
				TArray<CMDSDocument::RevisionInfo>	mDocumentRevisionInfos;
		};

	// DocumentFullInfosWithCount
	public:
		struct DocumentFullInfosWithTotalCount {
			// Methods
														// Lifecycle methods
														DocumentFullInfosWithTotalCount(UInt32 totalCount,
																const TArray<CMDSDocument::FullInfo>&
																		documentFullInfos) :
															mTotalCount(totalCount),
																	mDocumentFullInfos(documentFullInfos)
															{}
														DocumentFullInfosWithTotalCount(
																const DocumentFullInfosWithTotalCount& other) :
															mTotalCount(other.mTotalCount),
																	mDocumentFullInfos(other.mDocumentFullInfos)
															{}

														// Instance methods
						UInt32							getTotalCount() const
															{ return mTotalCount; }
				const	TArray<CMDSDocument::FullInfo>&	getDocumentFullInfos() const
															{ return mDocumentFullInfos; }
			// Properties
			private:
				UInt32							mTotalCount;
				TArray<CMDSDocument::FullInfo>	mDocumentFullInfos;
		};

	// Methods
	public:
		// Instance methods
		virtual	TVResult<DocumentRevisionInfosWithTotalCount>		associationGetDocumentRevisionInfosFrom(
																			const CString& name,
																			const CString& fromDocumentID,
																			UInt32 startIndex, const OV<UInt32>& count)
																			const = 0;
		virtual	TVResult<DocumentRevisionInfosWithTotalCount>		associationGetDocumentRevisionInfosTo(
																			const CString& name,
																			const CString& toDocumentID,
																			UInt32 startIndex, const OV<UInt32>& count)
																			const = 0;
		virtual	TVResult<DocumentFullInfosWithTotalCount>			associationGetDocumentFullInfosFrom(
																			const CString& name,
																			const CString& fromDocumentID,
																			UInt32 startIndex, const OV<UInt32>& count)
																			const = 0;
		virtual	TVResult<DocumentFullInfosWithTotalCount>			associationGetDocumentFullInfosTo(
																			const CString& name,
																			const CString& toDocumentID,
																			UInt32 startIndex, const OV<UInt32>& count)
																			const = 0;

		virtual	TVResult<TArray<CMDSDocument::RevisionInfo> >		collectionGetDocumentRevisionInfos(
																			const CString& name, UInt32 startIndex,
																			const OV<UInt32>& count) const = 0;
		virtual	TVResult<TArray<CMDSDocument::FullInfo> >			collectionGetDocumentFullInfos(const CString& name,
																			UInt32 startIndex, const OV<UInt32>& count)
																			const = 0;

		virtual	TVResult<TArray<CMDSDocument::RevisionInfo> >		documentRevisionInfos(const CString& documentType,
																			const TArray<CString>& documentIDs) const
																			= 0;
		virtual	TVResult<TArray<CMDSDocument::RevisionInfo> >		documentRevisionInfos(const CString& documentType,
																			UInt32 sinceRevision,
																			const OV<UInt32>& count) const = 0;
		virtual	TVResult<TArray<CMDSDocument::FullInfo> >			documentFullInfos(const CString& documentType,
																			const TArray<CString>& documentIDs) const
																			= 0;
		virtual	TVResult<TArray<CMDSDocument::FullInfo> >			documentFullInfos(const CString& documentType,
																			UInt32 sinceRevision,
																			const OV<UInt32>& count) const = 0;

		virtual	OV<SInt64>											documentIntegerValue(const CString& documentType,
																			const CMDSDocument& document,
																			const CString& property) const = 0;
		virtual	OV<CString>											documentStringValue(const CString& documentType,
																			const CMDSDocument& document,
																			const CString& property) const = 0;
		virtual	TVResult<TArray<CMDSDocument::FullInfo> >			documentUpdate(const CString& documentType,
																			const TArray<CMDSDocument::UpdateInfo>&
																					documentUpdateInfos) = 0;

		virtual	TVResult<TDictionary<CMDSDocument::RevisionInfo> >	indexGetDocumentRevisionInfos(const CString& name,
																			const TArray<CString>& keys);
		virtual	TVResult<TDictionary<CMDSDocument::FullInfo> >		indexGetDocumentFullInfos(const CString& name,
																			const TArray<CString>& keys);
};
