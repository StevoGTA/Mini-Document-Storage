//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDocumentBacking.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSSQLiteDocumentBacking

class CMDSSQLiteDatabaseManager;

class CMDSSQLiteDocumentBacking {
	// Procs
	public:
		typedef	void	(*Proc)(const I<CMDSSQLiteDocumentBacking>& documentBacking, void* userData);
		typedef	void	(*KeyProc)(const CString& key, const I<CMDSSQLiteDocumentBacking>& documentBacking,
								void* userData);

	// Classes
	private:
		class	Internals;

	// Methods
	public:
													// Lifecycle methods
													CMDSSQLiteDocumentBacking(SInt64 id, const CString& documentID,
															UInt32 revision, bool active,
															UniversalTime creationUniversalTime,
															UniversalTime modificationUniversalTime,
															const CDictionary& propertyMap,
															const CMDSDocument::AttachmentInfoByID&
																	documentAttachmentInfoByID);
													CMDSSQLiteDocumentBacking(const CString& documentType,
															const CString& documentID,
															const OV<UniversalTime>& creationUniversalTime,
															const OV<UniversalTime>& modificationUniversalTime,
															const CDictionary& propertyMap,
															CMDSSQLiteDatabaseManager& databaseManager);
													~CMDSSQLiteDocumentBacking();

													// Instance methods
				SInt64								getID() const;
		const	CString&							getDocumentID() const;
				UniversalTime						getCreationUniversalTime() const;

				UInt32								getRevision() const;
				bool								getActive() const;
				UniversalTime						getModificationUniversalTime() const;
				CDictionary							getPropertyMap() const;
				CMDSDocument::AttachmentInfoByID	getDocumentAttachmentInfoByID() const;

				CMDSDocument::FullInfo				getDocumentFullInfo() const;

				OV<SValue>							getValue(const CString& property) const;
				void								set(const CString& property, const OV<SValue>& value,
															const CString& documentType,
															CMDSSQLiteDatabaseManager& databaseManager);
				void								update(const CString& documentType,
															const OV<CDictionary>& updatedPropertyMap,
															const OV<const TSet<CString> >& removedProperties,
															CMDSSQLiteDatabaseManager& databaseManager);
				CMDSDocument::AttachmentInfo		attachmentAdd(const CString& documentType, const CDictionary& info,
															const CData& content,
															CMDSSQLiteDatabaseManager& databaseManager);
				CData								attachmentContent(const CString& documentType,
															const CString& attachmentID,
															CMDSSQLiteDatabaseManager& databaseManager);
				UInt32								attachmentUpdate(const CString& documentType,
															const CString& attachmentID,
															const CDictionary& updatedInfo, const CData& updatedContent,
															CMDSSQLiteDatabaseManager& databaseManager);
				void								attachmentRemove(const CString& documentType,
															const CString& attachmentID,
															CMDSSQLiteDatabaseManager& databaseManager);

	// Properties
	private:
		Internals*	mInternals;
};
