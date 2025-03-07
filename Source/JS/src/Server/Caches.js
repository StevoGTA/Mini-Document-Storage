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

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, statementPerformer, valueSelectorInfo) {
		// Store
		this.internals = internals;
		this.valueSelectorInfo = valueSelectorInfo;

		// Setup
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
	async register(statementPerformer, info) {
		// Validate
		if (!info || (typeof info != 'object'))
			return 'Missing info';

		let	name = info.name;
		if (!name)
			return 'Missing name';

		let	documentType = info.documentType;
		if (!documentType)
			return 'Missing documentType';

		let	relevantProperties = info.relevantProperties;
		if (!relevantProperties)
			return 'Missing relevantProperties';

		let	valueInfos = info.valueInfos;
		if (!valueInfos || !Array.isArray(valueInfos))
			return 'Missing valueInfos';

		for (let valueInfo of valueInfos) {
			// Setup
			let	name = valueInfo.name;
			if (!name)
				return 'Missing value name';

			let	valueType = valueInfo.valueType;
			if (!valueType)
				return 'Missing value valueType';
			if ((valueType != 'integer') && (valueType != 'string'))
				return 'Invalid value valueType: ' + valueType;

			let	selector = valueInfo.selector;
			if (!selector)
				return 'Missing value selector';
			if (!this.valueSelectorInfo[selector])
				return 'Invalid value selector: ' + selector;
		}

		// Setup
		let	internals = this.internals;

		// Check if need to create Caches table
		await internals.createTableIfNeeded(statementPerformer, this.cachesTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(true, this.cachesTable,
							[this.cachesTable.infoTableColumn],
							statementPerformer.where(this.cachesTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			let	cache = this.createCache(statementPerformer, name, documentType, relevantProperties, valueInfos, 0);

			statementPerformer.queueInsertInto(this.cachesTable,
					[
						{tableColumn: this.cachesTable.nameTableColumn, value: name},
						{tableColumn: this.cachesTable.typeTableColumn, value: documentType},
						{tableColumn: this.cachesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.cachesTable.infoTableColumn, value: JSON.stringify(valueInfos)},
						{tableColumn: this.cachesTable.lastDocumentRevisionTableColumn, value: 0},
					]);
			cache.queueCreate(statementPerformer);
		} else if (!util.isDeepStrictEqual(valueInfos, JSON.parse(results[0].info.toString()))) {
			// Update existing
			let	cache = this.createCache(statementPerformer, name, documentType, relevantProperties, valueInfos, 0);

			statementPerformer.queueReplace(this.cachesTable,
					[
						{tableColumn: this.cachesTable.nameTableColumn, value: name},
						{tableColumn: this.cachesTable.typeTableColumn, value: documentType},
						{tableColumn: this.cachesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.cachesTable.infoTableColumn, value: JSON.stringify(valueInfos)},
						{tableColumn: this.cachesTable.lastDocumentRevisionTableColumn, value: 0},
					]);
			cache.queueDrop(statementPerformer);
			cache.queueCreate(statementPerformer);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(statementPerformer, documentType) {
		// Catch errors
		try {
			// Select all Caches for this document type
			let	results =
						await statementPerformer.select(true, this.cachesTable,
								statementPerformer.where(this.cachesTable.typeTableColumn, documentType));
			
			var	caches = [];
			for (let result of results) {
				// Create Cache and update stuffs
				let	cache = 
							this.createCache(statementPerformer, result.name, result.type, result.relevantProperties,
									JSON.parse(result.info.toString()), result.lastDocumentRevision);
				caches.push(cache);
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
	async getForName(statementPerformer, name) {
		// Catch errors
		try {
			// Retrieve Cache
			let	results =
						await statementPerformer.select(true, this.cachesTable,
								statementPerformer.where(this.cachesTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Cache
				let	result = results[0];
				let	cache =
							this.createCache(statementPerformer, result.name, result.type, result.relevantProperties,
									JSON.parse(result.info.toString()), result.lastDocumentRevision);

				return [cache, null];
			} else
				// Don't have
				return [null, 'Unknown cache: ' + name];
		} catch(error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Caches'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getContent(statementPerformer, name, valueNames, documentIDs = null) {
		// Validate
		if (!name)
			return [null, null, 'Missing name'];

		if (!valueNames)
			return [null, null, 'Missing valueNames'];
		if (!Array.isArray(valueNames))
			return [null, null, 'valueNames is not an array.'];
		if (valueNames.length == 0)
			return [null, null, "Missing valueNames"];

		// Setup
		let	internals = this.internals;
		
		// Get cache
		let	[cache, cacheError] = await internals.caches.getForName(statementPerformer, name);
		if (cacheError)
			// Error
			return [null, null, cacheError];
		
		// Get document type last revision
		let	documentTypeLastRevision = await internals.documents.getLastRevision(statementPerformer, cache.type);

		// Check if up to date
		if (cache.lastDocumentRevision == documentTypeLastRevision) {
			// Get TableColumns
			let	documentIDTableColumn = internals.documents.getDocumentIDTableColumn(statementPerformer, cache.type);
			var	tableColumns = [documentIDTableColumn];
			for (let valueName of valueNames) {
				// Get TableColumn
				let	tableColumn = cache.tableColumn(valueName);
				if (!tableColumn)
					// Unknown cache valueName
					return [null, null, 'Unknown cache valueName: ' + valueName];
				
				// Add to array
				tableColumns.push(tableColumn);
			}
			
			// Check if have documentIDs
			var	mySQLResults;
			if (documentIDs != null)
				// Have documentIDs
				mySQLResults =
						await statementPerformer.select(true, cache.table, tableColumns,
								internals.documents.getInnerJoinForDocumentInfo(statementPerformer, cache.type,
										cache.table.idTableColumn),
								statementPerformer.where(documentIDTableColumn, documentIDs));
			else
				// Don't have documentIDs
				mySQLResults =
						await statementPerformer.select(true, cache.table, tableColumns,
								internals.documents.getInnerJoinForDocumentInfo(statementPerformer, cache.type,
										cache.table.idTableColumn));

			return [true, mySQLResults, null];
		} else if (documentTypeLastRevision) {
			// Update
			await internals.caches.updateCache(statementPerformer, cache);

			return [false, null, null];
		} else 
			// No document of this type yet
			return [true, [], null];
	}

	//------------------------------------------------------------------------------------------------------------------
	update(statementPerformer, caches, initialLastRevision, updateDocumentInfos) {
		// Iterate caches
		for (let cache of caches) {
			// Update
			if (cache.queueUpdates(statementPerformer, initialLastRevision, updateDocumentInfos)) {
				// Update table
				statementPerformer.queueUpdate(this.cachesTable,
						[
							{
								tableColumn: this.cachesTable.lastDocumentRevisionTableColumn,
								value: cache.lastDocumentRevision
							}
						],
						statementPerformer.where(this.cachesTable.nameTableColumn, cache.name));
			}
		}
	}

	// Internal methods
	//------------------------------------------------------------------------------------------------------------------
	async updateCache(statementPerformer, cache) {
		// Setup
		let	internals = this.internals;
		let	documentUpdateTracker = internals.getDocumentUpdateTrackerForCache(cache);

		// Get update document infos
		let	updateDocumentInfos =
					await internals.documents.getUpdateDocumentInfos(statementPerformer, cache.type,
							cache.lastDocumentRevision, 150);
		documentUpdateTracker.addDocumentInfos(updateDocumentInfos);
		
		// Perform updates
		await statementPerformer.batchLockedForWrite(documentUpdateTracker.tables(),
				() => { return (async() => {
					// Finalize DocumentUpdateTracker
					documentUpdateTracker.finalize(statementPerformer, cache.lastDocumentRevision);
				})()});
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	createCache(statementPerformer, name, type, relevantProperties, valueInfos, lastDocumentRevision) {
		// Setup
		let	valueInfosUse =
					valueInfos.map(valueInfo => {
							return {
								name: valueInfo.name,
								valueType: valueInfo.valueType,
								selector: this.valueSelectorInfo[valueInfo.selector],
							};
					})

		// Create cache
		return new Cache(statementPerformer, name, type, relevantProperties, valueInfosUse, lastDocumentRevision);
	}
}
