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

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, statementPerformer, isIncludedSelectorInfo) {
		// Store
		this.internals = internals;
		this.isIncludedSelectorInfo = isIncludedSelectorInfo;

		// Setup
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

		if (!('isUpToDate' in info))
			return 'Missing isUpToDate';
		let	isUpToDate = info.isUpToDate;

		let	isIncludedSelector = info.isIncludedSelector;
		if (!isIncludedSelector)
			return 'Missing isIncludedSelector';
		if (!this.isIncludedSelectorInfo[isIncludedSelector])
			return 'Invalid isIncludedSelector: ' + isIncludedSelector;

		let	isIncludedSelectorInfo = info.isIncludedSelectorInfo;
		if (!isIncludedSelectorInfo)
			return 'Missing isIncludedSelectorInfo';

		// Setup
		let	internals = this.internals;

		// Validate document type
		var	lastDocumentRevision = await internals.documents.getLastRevision(statementPerformer, documentType);
		if (lastDocumentRevision == null)
			return 'Unknown documentType: ' + documentType;

		// Check if need to create Collections table
		await internals.createTableIfNeeded(statementPerformer, this.collectionsTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(true, this.collectionsTable,
							[
								this.collectionsTable.isIncludedSelectorTableColumn,
								this.collectionsTable.isIncludedSelectorInfoTableColumn,
								this.collectionsTable.lastDocumentRevisionTableColumn,
							],
							statementPerformer.where(this.collectionsTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			if (!isUpToDate)
				// Reset last document revision
				lastDocumentRevision = 0;
			
			let	collection =
						new Collection(statementPerformer, name, documentType, relevantProperties,
								this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo,
								lastDocumentRevision);

			statementPerformer.queueInsertInto(this.collectionsTable,
					[
						{tableColumn: this.collectionsTable.nameTableColumn, value: name},
						{tableColumn: this.collectionsTable.typeTableColumn, value: documentType},
						{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn, value: isIncludedSelector},
						{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: JSON.stringify(isIncludedSelectorInfo)},
						{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn,
								value: lastDocumentRevision},
				]);
			collection.queueCreate(statementPerformer);
		} else if (isIncludedSelector != results[0].isIncludedSelector) {
			// Update to new isIncludedSelector
			lastDocumentRevision = isUpToDate ? results[0].lastDocumentRevision : 0;
			let	collection =
						new Collection(statementPerformer, name, documentType, relevantProperties,
								this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo,
								lastDocumentRevision);

			statementPerformer.queueUpdate(this.collectionsTable,
					[
						{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn, value: isIncludedSelector},
						{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: JSON.stringify(isIncludedSelectorInfo)},
						{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn,
								value: lastDocumentRevision},
					],
					statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			collection.queueTruncate(statementPerformer);
		} else if (!util.isDeepStrictEqual(isIncludedSelectorInfo, JSON.parse(results[0].isIncludedSelectorInfo))) {
			// isIncludedSelectorInfo has changed
			if (isUpToDate)
				// Updated info needed for future document changes
				statementPerformer.queueUpdate(this.collectionsTable,
						[{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
								value: JSON.stringify(isIncludedSelectorInfo)}],
								statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			else {
				// Need to rebuild this collection
				let	collection =
							new Collection(statementPerformer, name, documentType, relevantProperties,
									this.isIncludedSelectorInfo[isIncludedSelector], isIncludedSelectorInfo, 0);
				statementPerformer.queueUpdate(this.collectionsTable,
						[
							{tableColumn: this.collectionsTable.relevantPropertiesTableColumn,
									value: relevantProperties.toString()},
							{tableColumn: this.collectionsTable.isIncludedSelectorTableColumn,
									value: isIncludedSelector},
							{tableColumn: this.collectionsTable.isIncludedSelectorInfoTableColumn,
									value: JSON.stringify(isIncludedSelectorInfo)},
							{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn, value: 0},
						],
						statementPerformer.where(this.collectionsTable.nameTableColumn, name));
				collection.queueTruncate(statementPerformer);
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocumentCount(statementPerformer, name) {
		// Setup
		let	internals = this.internals;

		// Get collection
		let	[collection, collectionError] = await this.getForName(statementPerformer, name);
		if (collectionError)
			// Error
			return [null, null, collectionError];
		
		// Get document type last revision
		let	documentTypeLastRevision = await internals.documents.getLastRevision(statementPerformer, collection.type);

		// Check if up to date
		if (collection.lastDocumentRevision == documentTypeLastRevision) {
			// Setup
			let	count = await statementPerformer.count(collection.table);

			return [true, count, null];
		} else if (documentTypeLastRevision) {
			// Update
			await this.updateCollection(statementPerformer, collection);

			return [false, null, null];
		} else
			// No document of this type yet
			return [false, null, null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocuments(statementPerformer, name, startIndex, count, fullInfo) {
		// Validate
		if (startIndex < 0)
			return [null, null, null, 'Invalid startIndex: ' + startIndex];
		if ((count != null) && (count < 1))
			return [null, null, null, 'Invalid count: ' + count];

		// Setup
		let	internals = this.internals;

		// Get collection
		let	[collection, collectionError] = await this.getForName(statementPerformer, name);
		if (collectionError)
			// Error
			return [null, null, null, collectionError];
		
		// Get document type last revision
		let	documentTypeLastRevision = await internals.documents.getLastRevision(statementPerformer, collection.type);

		// Check if up to date
		if (collection.lastDocumentRevision == documentTypeLastRevision) {
			// Setup
			let	totalCount = await statementPerformer.count(collection.table);

			// Check for full info
			if (fullInfo) {
				// Documents
				let	[selectResults, documentsByID, resultsError] =
							await internals.documents.getDocuments(statementPerformer, collection.type,
									collection.table,
									internals.documents.getInnerJoinForDocument(statementPerformer, collection.type,
											collection.table.idTableColumn),
									null, statementPerformer.limit(startIndex, count));
				if (documentsByID)
					// Success
					return [true,
							(totalCount >= startIndex) ? totalCount - startIndex : 0, Object.values(documentsByID),
							null];
				else
					// Error
					return [null, null, null, resultsError];
			} else {
				// Document info
				let	[results, resultsError] =
							await internals.documents.getDocumentInfos(statementPerformer, collection.type,
									collection.table,
									internals.documents.getInnerJoinForDocumentInfo(statementPerformer, collection.type,
											collection.table.idTableColumn),
									null, statementPerformer.limit(startIndex, count));
				if (results)
					// Success
					return [true, totalCount,
							results.map(
									result => { return {documentID: result.documentID, revision: result.revision}; }),
							null];
				else
					// Error
					return [null, null, null, resultsError];
			}
		} else if (documentTypeLastRevision) {
			// Update
			await this.updateCollection(statementPerformer, collection);

			return [false, null, null, null];
		} else
			// No document of this type yet
			return [false, null, null, null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(statementPerformer, documentType) {
		// Catch errors
		try {
			// Select all Collections for this document type
			let	results =
						await statementPerformer.select(true, this.collectionsTable,
								statementPerformer.where(this.collectionsTable.typeTableColumn, documentType));
			
			var	collections = [];
			for (let result of results) {
				// Create Collection and update stuffs
				let	collection = 
							new Collection(statementPerformer, result.name, result.type,
									result.relevantProperties.split(','),
									this.isIncludedSelectorInfo[result.isIncludedSelector],
									JSON.parse(result.isIncludedSelectorInfo.toString()), result.lastDocumentRevision);
				collections.push(collection);
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
	async getForName(statementPerformer, name) {
		// Catch errors
		try {
			// Select all Collections with matching name
			let	results =
						await statementPerformer.select(true, this.collectionsTable,
								statementPerformer.where(this.collectionsTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Collection
				let	result = results[0];
				let	collection =
							new Collection(statementPerformer, result.name, result.type,
									result.relevantProperties.split(','),
									this.isIncludedSelectorInfo[result.isIncludedSelector],
									JSON.parse(result.isIncludedSelectorInfo.toString()), result.lastDocumentRevision);

				return [collection, null];
			} else
				// Don't have
				return [null, 'Unknown collection: ' + name];
		} catch(error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Collections'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	update(statementPerformer, collections, initialLastRevision, updateDocumentInfos) {
		// Iterate collections
		for (let collection of collections) {
			// Update
			if (collection.queueUpdates(statementPerformer, initialLastRevision, updateDocumentInfos)) {
				// Update table
				statementPerformer.queueUpdate(this.collectionsTable,
						[{tableColumn: this.collectionsTable.lastDocumentRevisionTableColumn,
									value: collection.lastDocumentRevision}],
						statementPerformer.where(this.collectionsTable.nameTableColumn, collection.name));
			}
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async updateCollection(statementPerformer, collection) {
		// Setup
		let	internals = this.internals;
		let	documentUpdateTracker = internals.getDocumentUpdateTrackerForCollection(collection);

		// Get update document infos
		let	updateDocumentInfos =
					await internals.documents.getUpdateDocumentInfos(statementPerformer, collection.type,
							collection.lastDocumentRevision, 150);
		documentUpdateTracker.addDocumentInfos(updateDocumentInfos);
		
		// Perform updates
		await statementPerformer.batchLockedForWrite(documentUpdateTracker.tables(),
				() => { return (async() => {
					// Finalize DocumentUpdateTracker
					documentUpdateTracker.finalize(statementPerformer, collection.lastDocumentRevision);
				})()});
	}
}
