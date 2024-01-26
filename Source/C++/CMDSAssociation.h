//----------------------------------------------------------------------------------------------------------------------
//	CMDSAssociation.h			©2023 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSAssociation

class CMDSAssociation : public CEquatable {
	// GetIntegerValueAction
	public:
		enum GetIntegerValueAction {
			kGetIntegerValueActionSum,
		};

	// Item
	public:
		struct Item {
			// Methods
			public:
												// Lifecycle methods
												Item(const CString& fromDocumentID, const CString& toDocumentID) :
													mFromDocumentID(fromDocumentID), mToDocumentID(toDocumentID)
													{}
												Item(const Item& other) :
													mFromDocumentID(other.mFromDocumentID),
															mToDocumentID(other.mToDocumentID)
													{}

												// Instance methods
						const	CString&		getFromDocumentID() const
													{ return mFromDocumentID; }
						const	CString&		getToDocumentID() const
													{ return mToDocumentID; }

								bool			operator==(const Item& other) const
													{ return (mFromDocumentID == other.mFromDocumentID) &&
															(mToDocumentID == other.mToDocumentID); }

			// Properties
			private:
				CString	mFromDocumentID;
				CString	mToDocumentID;
		};

	// Update
	public:
		struct Update {
			// Action
			enum Action {
				kActionAdd,
				kActionRemove,
			};

			// Methods
			public:
												// Lifecycle methods
												Update(const Update& other) :
													mAction(other.mAction), mItem(other.mItem)
													{}

												// Instance methods
								Action			getAction() const
													{ return mAction; }
						const	Item&			getItem() const
													{ return mItem; }

												// Class methods
				static			Update			add(const CString& fromDocumentID, const CString& toDocumentID)
													{ return Update(kActionAdd, fromDocumentID, toDocumentID); }
				static			Update			remove(const CString& fromDocumentID, const CString& toDocumentID)
													{ return Update(kActionRemove, fromDocumentID, toDocumentID); }

												// Class methods
				static			TArray<CString>	getFromDocumentIDs(const TArray<Update>& updates)
													{ return TNSet<CString>(updates,
																	(TNSet<CString>::ArrayMapProc)
																			getFromDocumentIDFromItem)
															.getArray(); }
				static			TArray<CString>	getToDocumentIDs(const TArray<Update>& updates)
													{ return TNSet<CString>(updates,
																	(TNSet<CString>::ArrayMapProc)
																			getToDocumentIDFromItem)
															.getArray(); }
				static			CString			getFromDocumentIDFromItem(const Update* update)
													{ return update->mItem.getFromDocumentID(); }
				static			CString			getToDocumentIDFromItem(const Update* update)
													{ return update->mItem.getToDocumentID(); }

			private:
												// Lifecycle methods
												Update(Action action, const CString& fromDocumentID,
														const CString& toDocumentID) :
													mAction(action), mItem(Item(fromDocumentID, toDocumentID))
													{}

			// Properties
			private:
				Action	mAction;
				Item	mItem;
		};

	// Methods
	public:
							// Lifecycle methods
							CMDSAssociation(const CString& name, const CString& fromDocumentType,
									const CString& toDocumentType) :
								mName(name), mFromDocumentType(fromDocumentType), mToDocumentType(toDocumentType)
								{}

							// CEquatable methods
				bool		operator==(const CEquatable& other) const
								{ return mName == ((const CMDSAssociation&) other).mName; }

							// Instance methods
		const	CString&	getName() const
								{ return mName; }
		const	CString&	getFromDocumentType() const
								{ return mFromDocumentType; }
		const	CString&	getToDocumentType() const
								{ return mToDocumentType; }

	// Properties
	private:
		CString	mName;
		CString	mFromDocumentType;
		CString	mToDocumentType;
};
