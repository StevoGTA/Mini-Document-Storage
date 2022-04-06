//
//  Collections.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Collection = require('./Collection');
let	util = require('util');

//----------------------------------------------------------------------------------------------------------------------
// Collections
module.exports = class Collections {

	// Properties
	collectionInfo = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, isIncludedSelectorInfo) {
		// Store
		this.internals = internals;
		this.isIncludedSelectorInfo = isIncludedSelectorInfo;

		// Setup
		let	statementPerformer = internals.statementPerformer;
		let	TableColumn = statementPerformer.tableColumn();
		this.collectionsTable =
				statementPerformer.table('Collections',
						[
							new TableColumn.VARCHAR('name',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									100),
							new TableColumn.VARCHAR('type', TableColumn.options.nonNull, 45),
							new TableColumn.VARCHAR('relevantProperties', TableColumn.options.nonNull, 200),
							new TableColumn.VARCHAR('isIncludedSelector', TableColumn.options.nonNull, 100),
							new TableColumn.LONGBLOB('isIncludedSelectorInfo', TableColumn.options.nonNull),
							new TableColumn.INT('lastDocumentRevision',
									TableColumn.options.nonNull | TableColumn.options.unsigned),
						]);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async register(info) {
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

		let	isUpToDate = info.isUpToDate;
		if (!isUpToDate)
			return 'Missing isUpToDate';

		let	isIncludedSelector = info.isIncludedSelector;
		if (!isIncludedSelector)
			return 'Missing isIncludedSelector';

		let	isIncludedSelectorInfo = info.isIncludedSelectorInfo;
		if (!isIncludedSelectorInfo)
			return 'Missing isIncludedSelectorInfo';

		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		// Check if need to create Collections table
		await internals.createTableIfNeeded(this.collectionsTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(this.collectionsTable,
							[
								this.collectionsTable.isIncludedSelectorTableColumn,
								this.collectionsTable.isIncludedSelectorInfoTableColumn,
								this.collectionsTable.lastDocumentRevisionTableColumn,
							],
							statementPerformer.where(this.collectionsTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			let	collection =
						new Collection(statementPerformer, name, relevantProperties,
								this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo, 0);
			this.collectionInfo[name] = collection;

			statementPerformer.queueInsertInto(this.collectionsTable,
					[
						{tableColumn: this.collectionsTable.nameTableColumn, value: name},
						{tableColumn: this.collectionsTable.typeTableColumn, value: documentType},
						{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn, value: isIncludedSelector},
						{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: isIncludedSelectorInfo},
						{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn, value: 0},
				]);
			collection.queueCreate();
		} else if (isIncludedSelector != results[0].isIncludedSelector) {
			// Update to new isIncludedSelector
			let	collection =
						new Collection(statementPerformer, name, relevantProperties,
								this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo, 0);
			this.collectionInfo[name] = collection;

			statementPerformer.queueUpdate(this.collectionsTable,
					[
						{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn, value: isIncludedSelector},
						{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: isIncludedSelectorInfo},
						{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn, value: 0},
					],
					statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			collection.queueTruncate();
		} else if (!util.isDeepStrictEqual(isIncludedSelectorInfo, JSON.parse(results[0].isIncludedSelectorInfo))) {
			// isIncludedSelectorInfo has changed
			if (isUpToDate) {
				// Updated info needed for future document changes
				let	collection =
							new Collection(statementPerformer, name, relevantProperties,
									this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo,
									results[0].lastDocumentRevision);
				this.collectionInfo[name] = collection;

				statementPerformer.queueUpdate(this.collectionsTable,
						[{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: isIncludedSelectorInfo}],
								statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			} else {
				// Need to rebuild this collection
				let	collection =
							new Collection(statementPerformer, name, relevantProperties,
									this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo, 0);
				this.collectionInfo[name] = collection;

				statementPerformer.queueUpdate(this.collectionsTable,
						[
							{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
									value: relevantProperties.toString()},
							{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn,
									value: isIncludedSelector},
							{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
									value: isIncludedSelectorInfo},
							{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn, value: 0},
						],
						statementPerformer.where(this.collectionsTable.nameTableColumn, name));
				collection.queueTruncate();
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(documentType) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Catch errors
		try {
			// Select all Collections for this document type
			let	results =
						await statementPerformer.select(this.collectionsTable,
								statementPerformer.where(this.collectionsTable.typeTableColumn, documentType));
			
			var	collections = [];
			for (let result of results) {
				// Create Collection and update stuffs
				let	collection = 
							new Collection(statementPerformer, result.name, result.relevantProperties,
									this.isIncludedSelectorInfo[result.isIncludedSelector],
									result.isIncludedSelectorInfo,
									result.lastDocumentRevision);
				collections.push(collection);
				this.collectionInfo[result.name] = collection;
			}

			return collections;
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
		var	collection = this.collectionInfo[name];
		if (collection)
			// Have
			return collection;

		// Catch errors
		try {
			// Select all Collections for this document type
			let	results =
						await statementPerformer.select(this.collectionsTable,
								statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Collection
				let	result = results[0];
				collection =
						new Collection(statementPerformer, result.name, result.relevantProperties,
								this.isIncludedSelectorInfo[result.isIncludedSelector], result.isIncludedSelectorInfo,
								result.lastDocumentRevision);
				this.collectionInfo[name] = collection;

				return collection;
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
	update(collections, initialLastRevision, updateDocumentInfos) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;
		
		// Iterate collections
		for (let collection of collections) {
			// Update
			if (collection.queueUpdates(initialLastRevision, updateDocumentInfos)) {
				// Update table
				statementPerformer.queueUpdate(this.collectionsTable,
						[{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn,
									value: collection.lastDocumentRevision}],
						statementPerformer.where(this.collectionsTable.nameTableColumn, collection.name));
			}
		}
	}
}
