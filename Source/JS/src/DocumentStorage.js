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
	constructor(statementPerformer, cacheValueSelectorInfo, collectionIsIncludedSelectorInfo, indexKeysSelectorInfo) {
		// Store
		this.statementPerformer = statementPerformer;
		this.cacheValueSelectorInfo = cacheValueSelectorInfo || {};
		this.collectionIsIncludedSelectorInfo = collectionIsIncludedSelectorInfo || {};
		this.indexKeysSelectorInfo = indexKeysSelectorInfo || {};
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async associationRegister(documentStorageID, info) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(() => { return internals.associations.register(info); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationUpdate(documentStorageID, name, infos) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() => { return internals.associations.update(name, infos); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfos(documentStorageID, name, fromDocumentID, toDocumentID, startIndex, fullInfo) {
// TODO: associationGetDocumentInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetValue(documentStorageID, name, toDocumentID, action, cacheName, cacheValueName) {
// TODO: associationGetValue
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheRegister(documentStorageID, info) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(() => { return internals.caches.register(info); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionRegister(documentStorageID, info) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(() => { return internals.collections.register(info); });
		
		return results;
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
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() => { return internals.documents.create(documentType, infos); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetSinceRevision(documentStorageID, documentType, sinceRevision, maxDocumentCount) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() =>
									{ return internals.documents.getSinceRevision(documentType, sinceRevision,
											maxDocumentCount); }
					);
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetForDocumentIDs(documentStorageID, documentType, documentIDs) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() => { return internals.documents.getForDocumentIDs(documentType, documentIDs); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdate(documentStorageID, documentType, infos) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() => { return internals.documents.update(documentType, infos); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentAdd(documentStorageID, documentType, documentID, info, content) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() =>
									{ return internals.documents.attachmentAdd(documentType, documentID, info,
											content); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentGet(documentStorageID, documentType, documentID, attachmentID) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() =>
									{ return internals.documents.attachmentGet(documentType, documentID,
											attachmentID); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentUpdate(documentStorageID, documentType, documentID, attachmentID, info, content) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() =>
									{ return internals.documents.attachmentUpdate(documentType, documentID,
											attachmentID, info, content); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentRemove(documentStorageID, documentType, documentID, attachmentID) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(
							() =>
									{ return internals.documents.attachmentRemove(documentType, documentID,
											attachmentID); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexRegister(documentStorageID, info) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(() => { return internals.indexes.register(info); });
		
		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocumentInfos(documentStorageID, name, keys) {
// TODO: indexGetDocumentInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoGet(documentStorageID, keys) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		let	{mySQLResults, results} =
					await internals.statementPerformer.batch(() => { return internals.info.get(keys); });

		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoSet(documentStorageID, keysAndValues) {
		// Setup
		let	internals = this.internals(documentStorageID);

		// Do it
		this.statementPerformer.use(documentStorageID);
		await internals.statementPerformer.batch(() => internals.info.set(keysAndValues));
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	internals(documentStorageID) {
		// Setup
		if (!this.documentStorageInfo[documentStorageID])
			// Create
			this.documentStorageInfo[documentStorageID] = {};
		
		// Setup internals
		var	internals = this.documentStorageInfo[documentStorageID].internals;
		if (!internals) {
			// Setup
			internals = new Internals(this.statementPerformer);
			internals.associations = new Associations(internals);
			internals.caches = new Caches(internals, this.cacheValueSelectorInfo);
			internals.collections = new Collections(internals, this.collectionIsIncludedSelectorInfo);
			internals.documents = new Documents(internals);
			internals.indexes = new Indexes(internals, this.indexKeysSelectorInfo);
			internals.info = new Info(internals);
	
			// Store
			this.documentStorageInfo[documentStorageID].internals = internals;
		}

		return internals;
	}
}
