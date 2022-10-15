//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDocumentBacking.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CDictionary.h"
#include "TimeAndDate.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSSQLiteDocumentBacking

class CMDSSQLiteDatabaseManager;

class CMDSSQLiteDocumentBackingInternals;
class CMDSSQLiteDocumentBacking {
	// Methods
	public:
						// Lifecycle methods
						CMDSSQLiteDocumentBacking(SInt64 id, UInt32 revision, UniversalTime creationUniversalTime,
								UniversalTime modificationUniversalTime, const CDictionary& propertyMap, bool active);
						CMDSSQLiteDocumentBacking(const CString& documentType, const CString& documentID,
								UniversalTime creationUniversalTime, UniversalTime modificationUniversalTime,
								const CDictionary& propertyMap, CMDSSQLiteDatabaseManager& databaseManager);
						~CMDSSQLiteDocumentBacking();

						// Instance methods
		SInt64			getID() const;
		UInt32			getRevision() const;
		UniversalTime	getCreationUniversalTime() const;
		UniversalTime	getModificationUniversalTime() const;

		OV<SValue>		getValue(const CString& property) const;
		void			set(const CString& property, const OV<SValue>& value, const CString& documentType,
								CMDSSQLiteDatabaseManager& databaseManager, bool commitChange = true);
		void			update(const CString& documentType, const CDictionary& updatedPropertyMap,
								const TSet<CString>& removedProperties, CMDSSQLiteDatabaseManager& databaseManager,
								bool commitChange = true);

	// Properties
	private:
		CMDSSQLiteDocumentBackingInternals*	mInternals;
};
