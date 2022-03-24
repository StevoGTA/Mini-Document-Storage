//
//  Internals.js
//
//  Created by Stevo on 2/10/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports

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
		this.collectionsToUpdate = cachesToUpdate;

		this.indexes = indexes;
		this.indexesToUpdate = indexesToUpdate;
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	tables() {
		// Return tables
		return [this.caches.cachesTable, this.collections.collectionsTable, this.indexes.indexesTable]
				.concat(this.cachesToUpdate.map(cache => cache.table))
				.concat(this.collectionsToUpdate.map(collection => collection.table))
				.concat(this.indexesToUpdate.map(index => index.table));
	}

	//------------------------------------------------------------------------------------------------------------------
	addDocumentInfo(documentInfo) { this.documentInfos.push(documentInfo); }

	//------------------------------------------------------------------------------------------------------------------
	finalize(initialLastRevision) {
		// Update
		this.caches.update(this.cachesToUpdate, initialLastRevision, this.documentInfos);
		this.collections.update(this.collectionsToUpdate, initialLastRevision, this.documentInfos);
		this.indexes.update(this.indexesToUpdate, initialLastRevision, this.documentInfos);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// Internals
module.exports = class Internals {

	// Properties
	// statementPerformer = null;

	cache = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer) {
		// Store
		this.statementPerformer = statementPerformer;

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
	async getInfo(keys) {
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
							await this.statementPerformer.select(this.table,
									[this.table.keyTableColumn, this.table.valueTableColumn],
									this.statementPerformer.where(this.table.keyTableColumn, keysToRetrieve));

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
	queueUpdateInfo(info) {
		// Check if need to create table
		if (!this.haveTable)
			// Create table
			this.statementPerformer.queueCreateTable(this.table);

		// Iterate info
		for (let [key, value] of Object.entries(info))
			// Add statement for this entry
			this.statementPerformer.queueReplace(this.table,
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

	//------------------------------------------------------------------------------------------------------------------
	async createTableIfNeeded(table) {
		// Create table if needed
		let	tableVersionKey = table.name + 'TableVersion';
		let	tableVersion = (await this.getInfo([tableVersionKey]))[tableVersionKey];
		if (!tableVersion) {
			// Create table
			this.statementPerformer.queueCreateTable(table);

			// Set version
			let	info = {};
			info[tableVersionKey] = 1;
			this.queueUpdateInfo(info);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocumentUpdateTracker(documentType) {
		// Setup
		let	cachesToUpdate = await this.caches.getForDocumentType(documentType);
		let	collectionsToUpdate = await this.collections.getForDocumentType(documentType);
		let	indexesToUpdate = await this.indexes.getForDocumentType(documentType);

		return new DocumentUpdateTracker(this.caches, cachesToUpdate, this.collections, collectionsToUpdate,
				this.indexes, indexesToUpdate);
	}
};
