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
		this.cacheValueSelectorInfo = cacheValueSelectorInfo || {};
		this.collectionIsIncludedSelectorInfo = collectionIsIncludedSelectorInfo || {};
		this.indexKeysSelectorInfo = indexKeysSelectorInfo || {};
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
						await statementPerformer.batch(
								() => { return internals.associations.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
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
						await statementPerformer.batch(
								() => { return internals.associations.update(statementPerformer, name, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfos(documentStorageID, name, fromDocumentID, toDocumentID, startIndex, documentCount,
			fullInfo) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(
								() =>
										{ return internals.associations.getDocumentInfos(statementPerformer, name,
												fromDocumentID, toDocumentID, startIndex, documentCount, fullInfo); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetValue(documentStorageID, name, toDocumentID, action, cacheName, cacheValueName) {
// TODO: associationGetValue
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
						await statementPerformer.batch(
								() => { return internals.caches.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
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
						await statementPerformer.batch(
								() => { return internals.collections.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentCount(documentStorageID, name) {
// TODO: collectionGetDocumentCount
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentInfos(documentStorageID, name, startIndex) {
// TODO: collectionGetDocumentInfos(documentStorageID, name, startIndex) {

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
						await statementPerformer.batch(
								() => { return internals.documents.create(statementPerformer, documentType, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetSinceRevision(documentStorageID, documentType, sinceRevision, maxDocumentCount) {
		// Setup
		let	statementPerformer = this.statementPerformerProc();
		statementPerformer.use(documentStorageID);

		let	internals = this.internals(statementPerformer, documentStorageID);

		// Catch errors
		try {
			// Do it
			let	{mySQLResults, results} =
						await statementPerformer.batch(
								() =>
										{ return internals.documents.getSinceRevision(statementPerformer, documentType,
												sinceRevision, maxDocumentCount); }
						);
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() =>
										{ return internals.documents.getForDocumentIDs(statementPerformer, documentType,
												documentIDs); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() => { return internals.documents.update(statementPerformer, documentType, infos); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() =>
										{ return internals.documents.attachmentAdd(statementPerformer, documentType,
												documentID, info, content); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() =>
										{ return internals.documents.attachmentGet(statementPerformer, documentType,
												documentID, attachmentID); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() =>
										{ return internals.documents.attachmentUpdate(statementPerformer, documentType,
												documentID, attachmentID, info, content); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
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
						await statementPerformer.batch(
								() =>
										{ return internals.documents.attachmentRemove(statementPerformer, documentType,
												documentID, attachmentID); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
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
						await statementPerformer.batch(
								() => { return internals.indexes.register(statementPerformer, info); });
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
			else
				// Other
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocumentInfos(documentStorageID, name, keys) {
// TODO: indexGetDocumentInfos
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
						await statementPerformer.batch(() => { return internals.info.get(statementPerformer, keys); });

			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return [null, 'Invalid documentStorageID'];
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
						await statementPerformer.batch(
								() => internals.info.set(statementPerformer, keysAndValues));
			
			return results;
		} catch (error) {
			// Error
			if (statementPerformer.isUnknownDatabaseError(error))
				// Unknown database
				return 'Invalid documentStorageID';
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
	
			// Store
			this.documentStorageInfo[documentStorageID].internals = internals;
		}

		return internals;
	}
}
