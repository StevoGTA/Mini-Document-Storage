//
//  Internals.js
//
//  Created by Stevo on 2/10/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// DocumentUpdateTracker
class DocumentUpdateTracker {

	// Properties
	documentInfos = [];

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(caches, cachesToUpdate, collections, collectionsToUpdate, indexes, indexesToUpdate) {
		// Store
		this.caches = caches;
		this.cachesToUpdate = cachesToUpdate;

		this.collections = collections;
		this.collectionsToUpdate = collectionsToUpdate;

		this.indexes = indexes;
		this.indexesToUpdate = indexesToUpdate;
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	tables() {
		// Setup
		var	tables = [];
		if (this.caches)		tables.push(this.caches.cachesTable);
		if (this.collections)	tables.push(this.collections.collectionsTable);
		if (this.indexes)		tables.push(this.indexes.indexesTable);

		return tables
				.concat(this.cachesToUpdate.map(cache => cache.table))
				.concat(this.collectionsToUpdate.map(collection => collection.table))
				.concat(this.indexesToUpdate.map(index => index.table));
	}

	//------------------------------------------------------------------------------------------------------------------
	addDocumentInfo(documentInfo) { this.documentInfos.push(documentInfo); }

	//------------------------------------------------------------------------------------------------------------------
	addDocumentInfos(documentInfos) { this.documentInfos = this.documentInfos.concat(documentInfos); }

	//------------------------------------------------------------------------------------------------------------------
	finalize(statementPerformer, initialLastRevision) {
		// Update
		if (this.caches)
			// Update caches
			this.caches.update(statementPerformer, this.cachesToUpdate, initialLastRevision, this.documentInfos);

		if (this.collections)
			// Update collections
			this.collections.update(statementPerformer, this.collectionsToUpdate, initialLastRevision,
					this.documentInfos);

		if (this.indexes)
			// Update indexes
			this.indexes.update(statementPerformer, this.indexesToUpdate, initialLastRevision, this.documentInfos);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// Internals
module.exports = class Internals {

	// Properties
	cache = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer) {
		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		this.table =
				statementPerformer.table('Internals',
						[
							new TableColumn.VARCHAR('key',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									767),
							new TableColumn.VARCHAR('value', TableColumn.options.nonNull, 45),
						]);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async createTableIfNeeded(statementPerformer, table) {
		// Create table if needed
		let	tableVersionKey = table.name + 'TableVersion';
		let	tableVersion = (await this.getInfo(statementPerformer, [tableVersionKey]))[tableVersionKey];
		if (!tableVersion) {
			// Create table
			statementPerformer.queueCreateTable(table);

			// Set version
			let	info = {};
			info[tableVersionKey] = 1;
			this.queueUpdateInfo(statementPerformer, info);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocumentUpdateTracker(statementPerformer, documentType) {
		// Setup
		let	cachesToUpdate = await this.caches.getForDocumentType(statementPerformer, documentType);
		let	collectionsToUpdate = await this.collections.getForDocumentType(statementPerformer, documentType);
		let	indexesToUpdate = await this.indexes.getForDocumentType(statementPerformer, documentType);

		return new DocumentUpdateTracker(this.caches, cachesToUpdate, this.collections, collectionsToUpdate,
				this.indexes, indexesToUpdate);
	}

	//------------------------------------------------------------------------------------------------------------------
	getDocumentUpdateTrackerForCache(cache) {
		// Return DocumentUpdateTracker
		return new DocumentUpdateTracker(this.caches, [cache], null, [], null, []);
	}

	//------------------------------------------------------------------------------------------------------------------
	getDocumentUpdateTrackerForCollection(collection) {
		// Return DocumentUpdateTracker
		return new DocumentUpdateTracker(null, [], this.collections, [collection], null, []);
	}

	//------------------------------------------------------------------------------------------------------------------
	getDocumentUpdateTrackerForIndex(index) {
		// Return DocumentUpdateTracker
		return new DocumentUpdateTracker(null, [], null, [], this.indexes, [index]);
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async getInfo(statementPerformer, keys) {
		// Check cache
		var	info = {};
		var	keysToRetrieve = [];
		for (let key of keys) {
			// Check cache
			if (this.cache[key])
				// Have in cache
				info[key] = this.cache[key];
			else
				// Not in cache
				keysToRetrieve.push(key);
		}

		// Check if have anything to retrieve
		if (keysToRetrieve.length > 0)
			// Catch errors
			try {
				// Perform
				let	results =
							await statementPerformer.select(this.table,
									[this.table.keyTableColumn, this.table.valueTableColumn],
									statementPerformer.where(this.table.keyTableColumn, keysToRetrieve));

				// Iterate results
				for (let result of results) {
					// Update stuffs
					info[result.key] = result.value;
					this.cache[result.key] = result.value;
				}

				// Update
				this.haveTable = true;
			} catch (error) {
				// Check error
				if (!error.message.startsWith('ER_NO_SUCH_TABLE'))
					// Other error
					throw error;
			}

		return info;
	}

	//------------------------------------------------------------------------------------------------------------------
	queueUpdateInfo(statementPerformer, info) {
		// Check if need to create table
		if (!this.haveTable)
			// Create table
			statementPerformer.queueCreateTable(this.table);

		// Iterate info
		for (let [key, value] of Object.entries(info))
			// Add statement for this entry
			statementPerformer.queueReplace(this.table,
					[
						{tableColumn: this.table.keyTableColumn, value: key},
						{tableColumn: this.table.valueTableColumn, value: value},
					]);

		// Iterate info
		for (let [key, value] of Object.entries(info))
			// Update cache
			this.cache[key] = value;
		
		// Update
		this.haveTable = true;
	}
};
