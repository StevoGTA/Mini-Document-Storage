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

	// Types
	typedef	TVResult<TDictionary<CMDSDocument::FullInfo> >		DocumentFullInfoDictionaryResult;
	typedef	TVResult<TArray<CMDSDocument::FullInfo> >			DocumentFullInfosResult;
	typedef	TVResult<DocumentFullInfosWithTotalCount>			DocumentFullInfosWithTotalCountResult;
	typedef	TVResult<TDictionary<CMDSDocument::RevisionInfo> >	DocumentRevisionInfoDictionaryResult;
	typedef	TVResult<TArray<CMDSDocument::RevisionInfo> >		DocumentRevisionInfosResult;
	typedef	TVResult<DocumentRevisionInfosWithTotalCount>		DocumentRevisionInfosWithTotalCountResult;

	// Methods
	public:
															// Lifecycle methods
															CMDSDocumentStorageServer() : CMDSDocumentStorage() {}

															// Instance methods
		virtual	DocumentRevisionInfosWithTotalCountResult	associationGetDocumentRevisionInfosFrom(const CString& name,
																	const CString& fromDocumentID, UInt32 startIndex,
																	const OV<UInt32>& count) const = 0;
		virtual	DocumentRevisionInfosWithTotalCountResult	associationGetDocumentRevisionInfosTo(const CString& name,
																	const CString& toDocumentID, UInt32 startIndex,
																	const OV<UInt32>& count) const = 0;
		virtual	DocumentFullInfosWithTotalCountResult		associationGetDocumentFullInfosFrom(const CString& name,
																	const CString& fromDocumentID, UInt32 startIndex,
																	const OV<UInt32>& count) const = 0;
		virtual	DocumentFullInfosWithTotalCountResult		associationGetDocumentFullInfosTo(const CString& name,
																	const CString& toDocumentID, UInt32 startIndex,
																	const OV<UInt32>& count) const = 0;

		virtual	DocumentRevisionInfosResult					collectionGetDocumentRevisionInfos(const CString& name,
																	UInt32 startIndex, const OV<UInt32>& count) const
																	= 0;
		virtual	DocumentFullInfosResult						collectionGetDocumentFullInfos(const CString& name,
																	UInt32 startIndex, const OV<UInt32>& count) const
																	= 0;

		virtual	DocumentRevisionInfosResult					documentRevisionInfos(const CString& documentType,
																	const TArray<CString>& documentIDs) const = 0;
		virtual	DocumentRevisionInfosResult					documentRevisionInfos(const CString& documentType,
																	UInt32 sinceRevision, const OV<UInt32>& count) const
																	= 0;
		virtual	DocumentFullInfosResult						documentFullInfos(const CString& documentType,
																	const TArray<CString>& documentIDs) const = 0;
		virtual	DocumentFullInfosResult						documentFullInfos(const CString& documentType,
																	UInt32 sinceRevision, const OV<UInt32>& count) const
																	= 0;

		virtual	OV<SInt64>									documentIntegerValue(const CString& documentType,
																	const CMDSDocument& document,
																	const CString& property) const = 0;
		virtual	OV<CString>									documentStringValue(const CString& documentType,
																	const CMDSDocument& document,
																	const CString& property) const = 0;
		virtual	DocumentFullInfosResult						documentUpdate(const CString& documentType,
																	const TArray<CMDSDocument::UpdateInfo>&
																			documentUpdateInfos) = 0;

		virtual	DocumentRevisionInfoDictionaryResult		indexGetDocumentRevisionInfos(const CString& name,
																	const TArray<CString>& keys) const = 0;
		virtual	DocumentFullInfoDictionaryResult			indexGetDocumentFullInfos(const CString& name,
																	const TArray<CString>& keys) const = 0;
};
