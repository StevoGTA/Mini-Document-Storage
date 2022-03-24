//
//  Caches.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Cache = require('./Cache');
let	util = require('util');

//----------------------------------------------------------------------------------------------------------------------
// Caches
module.exports = class Caches {

	// Properties
	cacheInfo = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, valueSelectorInfo) {
		// Store
		this.internals = internals;
		this.valueSelectorInfo = valueSelectorInfo;

		// Setup
		let	statementPerformer = internals.statementPerformer;
		let	TableColumn = statementPerformer.tableColumn();
		this.cachesTable =
				statementPerformer.table('Caches',
						[
							new TableColumn.VARCHAR('name',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									100),
							new TableColumn.VARCHAR('type', TableColumn.options.nonNull, 45),
							new TableColumn.VARCHAR('relevantProperties', TableColumn.options.nonNull, 200),
							new TableColumn.LONGBLOB('info', TableColumn.options.nonNull),
							new TableColumn.INT('lastDocumentRevision',
									TableColumn.options.nonNull | TableColumn.options.unsigned),
						]);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async register(info) {
		// Setup
		let	name = info.name;
		let	documentType = info.documentType;
		let	relevantProperties = info.relevantProperties;
		let	valuesInfos = info.valuesInfos;

		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		// Validate info
		if (!name || !documentType || !relevantProperties || !valuesInfos)
			return 'Missing required info';
		for (let valueInfo of valuesInfos) {
			// Setup
			let	name = valueInfo.name;
			let	valueType = valueInfo.valueType;
			let	selector = valueInfo.selector;
			if (!name || !valueType || !selector)
				return 'Missing required info';
			if (valueType != 'integer')
				return 'Unsupported value type: ' + valueType;
		}

		// Check if need to create Caches table
		await internals.createTableIfNeeded(this.cachesTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(this.cachesTable,
							[this.cachesTable.infoTableColumn],
							statementPerformer.where(this.cachesTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			let	cache = this.createCache(statementPerformer, name, relevantProperties, valuesInfos, 0);
			this.cacheInfo[name] = cache;

			statementPerformer.queueInsertInto(this.cachesTable,
					[
						{tableColumn: this.cachesTable.nameTableColumn, value: name},
						{tableColumn: this.cachesTable.typeTableColumn, value: documentType},
						{tableColumn: this.cachesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.cachesTable.infoTableColumn, value: valuesInfos},
						{tableColumn: this.cachesTable.lastDocumentRevisionTableColumn, value: 0},
					]);
			cache.queueCreate();
		} else {
			// Have existing
			if (!util.isDeepStrictEqual(valuesInfos, JSON.parse(results[0].info.toString()))) {
				// Update
				let	cache = this.createCache(statementPerformer, name, relevantProperties, valuesInfos, 0);
				this.cacheInfo[name] = cache;

				statementPerformer.queueReplace(this.cachesTable,
						[
							{tableColumn: this.cachesTable.nameTableColumn, value: name},
							{tableColumn: this.cachesTable.typeTableColumn, value: documentType},
							{tableColumn: this.cachesTable.relevantPropertiesTableColumn,
									value: relevantProperties.toString()},
							{tableColumn: this.cachesTable.infoTableColumn, value: valuesInfos},
							{tableColumn: this.cachesTable.lastDocumentRevisionTableColumn, value: 0},
						]);
				cache.queueTruncate();
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(documentType) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Catch errors
		try {
			// Select all Caches for this document type
			let	results =
						await statementPerformer.select(this.cachesTable,
								statementPerformer.where(this.cachesTable.typeTableColumn, documentType));
			
			var	caches = [];
			for (let result of results) {
				// Create Cache and update stuffs
				let	cache = 
							this.createCache(statementPerformer, result.name, result.relevantProperties, result.info,
									result.lastDocumentRevision);
				caches.push(cache);
				this.cacheInfo[result.name] = cache;
			}

			return caches;
		} catch(error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForName(name) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Check if already have
		var	cache = this.cacheInfo[name];
		if (cache)
			// Have
			return cache;

		// Catch errors
		try {
			// Select all Caches for this document type
			let	results =
						await statementPerformer.select(this.cachesTable,
								statementPerformer.where(this.cachesTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Cache
				let	result = results[0];
				cache =
						this.createCache(statementPerformer, result.name, result.relevantProperties, result.info,
								result.lastDocumentRevision);
				this.cacheInfo[name] = cache;

				return cache;
			} else
				// Don't have
				return null;
		} catch(error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return null;
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	update(caches, initialLastRevision, updateDocumentInfos) {
		// Iterate caches
		for (let cache of caches) {
			// Update
			if (cache.queueUpdates(initialLastRevision, updateDocumentInfos)) {
				// Update table
				internals.statementPerformer.queueUpdate(this.cachesTable,
						[{tableColumn: this.cachesTable.lastDocumentRevisionTableColumn,
									value: cache.lastDocumentRevision}],
						internals.statementPerformer.where(this.cachesTable.nameTableColumn, cache.name));
			}
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	createCache(name, relevantProperties, valuesInfos, lastDocumentRevision) {
		// Setup
		let	valuesInfosUse =
					valuesInfos.map(info => {
							return {
								name: info.name,
								valueType: info.valueType,
								selector: this.valueSelectorInfo[info.selector],
							};
					})

		// Create cache
		return new Cache(this.internals.statementPerformer, name, relevantProperties, valuesInfosUse,
				lastDocumentRevision);
	}
}
