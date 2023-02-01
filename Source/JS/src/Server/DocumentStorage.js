//
//  DocumentStorage.js
//
//  Created by Stevo on 1/19/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Associations = require('./Associations');
let	Caches = require('./Caches');
let	Collections = require('./Collections');
let	Documents = require('./Documents');
let	Indexes = require('./Indexes');
let	Info = require('./Info');
let	Internal = require('./Internal');
let Internals = require('./Internals');

//----------------------------------------------------------------------------------------------------------------------
// DocumentStorage
module.exports = class DocumentStorage {

	// Properties
	documentStorageInfo = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformerProc, cacheValueSelectorInfo, collectionIsIncludedSelectorInfo,
			indexKeysSelectorInfo) {
		// Store
		this.statementPerformerProc = statementPerformerProc;
		this.cacheValueSelectorInfo =
				Object.assign(
						{
							'integerValueForProperty()': integerValueForProperty,
						},
						cacheValueSelectorInfo || {});
		this.collectionIsIncludedSelectorInfo =
				Object.assign(
						{
							'documentPropertyIsValue()': documentPropertyIsValue,
						},
						collectionIsIncludedSelectorInfo || {});
		this.indexKeysSelectorInfo =
				Object.assign(
						{
							'keysForDocumentProperty()': keysForDocumentProperty,
						},
						indexKeysSelectorInfo || {});
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async associationRegister(documentStorageID, info) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.associations.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationUpdate(documentStorageID, name, infos) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.associations.update(statementPerformer, name, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocuments(documentStorageID, name, fromDocumentID, toDocumentID, startIndex, count, fullInfo) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.associations.getDocuments(statementPerformer, name,
												fromDocumentID, toDocumentID, startIndex, count, fullInfo); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetValue(documentStorageID, name, action, fromDocumentIDs, cacheName, cachedValueNames) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.associations.getValue(statementPerformer, name, action,
												fromDocumentIDs, cacheName, cachedValueNames); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheRegister(documentStorageID, info) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.caches.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionRegister(documentStorageID, info) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.collections.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentCount(documentStorageID, name) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.collections.getDocumentCount(statementPerformer,
												name); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocuments(documentStorageID, name, startIndex, count, fullInfo) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.collections.getDocuments(statementPerformer, name,
												startIndex, count, fullInfo); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentCreate(documentStorageID, documentType, infos) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.documents.create(statementPerformer, documentType, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetCount(documentStorageID, documentType) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.documents.getCount(statementPerformer, documentType); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetSinceRevision(documentStorageID, documentType, sinceRevision, count) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.getSinceRevision(statementPerformer, documentType,
												sinceRevision, count); }
						);
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetForDocumentIDs(documentStorageID, documentType, documentIDs) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.getForDocumentIDs(statementPerformer, documentType,
												documentIDs); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdate(documentStorageID, documentType, infos) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.documents.update(statementPerformer, documentType, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentAdd(documentStorageID, documentType, documentID, info, content) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.attachmentAdd(statementPerformer, documentType,
												documentID, info, content); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentGet(documentStorageID, documentType, documentID, attachmentID) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.attachmentGet(statementPerformer, documentType,
												documentID, attachmentID); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentUpdate(documentStorageID, documentType, documentID, attachmentID, info, content) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.attachmentUpdate(statementPerformer, documentType,
												documentID, attachmentID, info, content); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentRemove(documentStorageID, documentType, documentID, attachmentID) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.documents.attachmentRemove(statementPerformer, documentType,
												documentID, attachmentID); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexRegister(documentStorageID, info) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.indexes.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocuments(documentStorageID, name, keys, fullInfo) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() =>
										{ return internals.indexes.getDocuments(statementPerformer, name, keys,
												fullInfo); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoGet(documentStorageID, keys) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.info.get(statementPerformer, keys); });

			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoSet(documentStorageID, keysAndValues) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => internals.info.set(statementPerformer, keysAndValues));
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async internalGet(documentStorageID, keys) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => { return internals.internal.get(statementPerformer, keys); });

			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID: ' + documentStorageID];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async internalSet(documentStorageID, keysAndValues) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(true,
								() => internals.internal.set(statementPerformer, keysAndValues));
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID: ' + documentStorageID;
			else
				// Other
				throw error;
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	internals(statementPerformer, documentStorageID) {
		// Setup
		if (!this.documentStorageInfo[documentStorageID])
			// Create
			this.documentStorageInfo[documentStorageID] = {};
		
		// Setup internals
		var	internals = this.documentStorageInfo[documentStorageID].internals;
		if (!internals) {
			// Setup
			internals = new Internals(statementPerformer);
			internals.associations = new Associations(internals, statementPerformer);
			internals.caches = new Caches(internals, statementPerformer, this.cacheValueSelectorInfo);
			internals.collections =
					new Collections(internals, statementPerformer, this.collectionIsIncludedSelectorInfo);
			internals.documents = new Documents(internals, statementPerformer);
			internals.indexes = new Indexes(internals, statementPerformer, this.indexKeysSelectorInfo);
			internals.info = new Info(internals, statementPerformer);
			internals.internal = new Internal(internals, statementPerformer);
	
			// Store
			this.documentStorageInfo[documentStorageID].internals = internals;
		}

		return internals;
	}
}

// Built-in Cache functions
//----------------------------------------------------------------------------------------------------------------------
function integerValueForProperty(info, property) { return info[property] || 0; }

// Built-in Collection functions
//----------------------------------------------------------------------------------------------------------------------
function documentPropertyIsValue(info, selectorInfo) {
	// Setup
	let	property = selectorInfo.property;
	let	value = selectorInfo.value;
	
	return property && value && (info[property] == value);
}

// Built-in Index functions
//----------------------------------------------------------------------------------------------------------------------
function keysForDocumentProperty(info, selectorInfo) {
	// Retrieve and check property
	let	property = selectorInfo.property;
	if (!property)	return [];

	// Retrieve value
	let	value = info[property];

	return value ? [value] : [];
}
