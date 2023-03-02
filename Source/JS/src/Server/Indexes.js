//
//  Indexes.js
//
//  Created by Stevo on 2/22/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Index = require('./Index');
let	util = require('util');

//----------------------------------------------------------------------------------------------------------------------
// Indexes
module.exports = class Indexes {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, statementPerformer, keysSelectorInfo) {
		// Store
		this.internals = internals;
		this.keysSelectorInfo = keysSelectorInfo;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		this.indexesTable =
				statementPerformer.table('Indexes',
						[
							new TableColumn.VARCHAR('name',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									100),
							new TableColumn.VARCHAR('type', TableColumn.options.nonNull, 45),
							new TableColumn.VARCHAR('relevantProperties', TableColumn.options.nonNull, 200),
							new TableColumn.VARCHAR('keysSelector', TableColumn.options.nonNull, 100),
							new TableColumn.LONGBLOB('keysSelectorInfo', TableColumn.options.nonNull),
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

		let	keysSelector = info.keysSelector;
		if (!keysSelector)
			return 'Missing keysSelector';
		if (!this.keysSelectorInfo[keysSelector])
			return 'Invalid keysSelector: ' + keysSelector;

		let	keysSelectorInfo = info.keysSelectorInfo;
		if (!keysSelectorInfo)
			return 'Missing keysSelectorInfo';

		// Setup
		let	internals = this.internals;

		// Validate document type
		var	lastDocumentRevision = await internals.documents.getLastRevision(statementPerformer, documentType);
		if (lastDocumentRevision == null)
			return 'Unknown documentType: ' + documentType;

		// Check if need to create Indexes table
		await internals.createTableIfNeeded(statementPerformer, this.indexesTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(true, this.indexesTable,
							[
								this.indexesTable.keysSelectorTableColumn,
								this.indexesTable.keysSelectorInfoTableColumn,
								this.indexesTable.lastDocumentRevisionTableColumn,
							],
							statementPerformer.where(this.indexesTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			lastDocumentRevision = 0;
			
			// Create index
			let	index =
						new Index(statementPerformer, name, documentType, relevantProperties,
								this.keysSelectorInfo[keysSelector], keysSelectorInfo, lastDocumentRevision);

			// Update database
			statementPerformer.queueInsertInto(this.indexesTable,
					[
						{tableColumn: this.indexesTable.nameTableColumn, value: name},
						{tableColumn: this.indexesTable.typeTableColumn, value: documentType},
						{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
						{tableColumn: this.indexesTable.keysSelectorInfoTableColumn,
								value: JSON.stringify(keysSelectorInfo)},
						{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: lastDocumentRevision},
				]);
			index.queueCreate(statementPerformer);
		} else if (keysSelector != results[0].keysSelector) {
			// Update to new keysSelector
			lastDocumentRevision = 0;
			let	index =
						new Index(statementPerformer, name, documentType, relevantProperties,
								this.keysSelectorInfo[keysSelector], keysSelectorInfo, lastDocumentRevision);

			statementPerformer.queueUpdate(this.indexesTable,
					[
						{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
						{tableColumn: this.indexesTable.keysSelectorInfoTableColumn,
								value: JSON.stringify(keysSelectorInfo)},
						{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: lastDocumentRevision},
					],
					statementPerformer.where(this.indexesTable.nameTableColumn, name));
			index.queueTruncate(statementPerformer);
		} else if (!util.isDeepStrictEqual(keysSelectorInfo, JSON.parse(results[0].keysSelectorInfo))) {
			// keysSelectorInfo has changed
			let	index =
					new Index(statementPerformer, name, documentType, relevantProperties,
							this.keysSelectorInfo[keysSelector], keysSelectorInfo, 0);

			statementPerformer.queueUpdate(this.indexesTable,
					[
						{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
						{tableColumn: this.indexesTable.keysSelectorInfoTableColumn,
								value: JSON.stringify(keysSelectorInfo)},
						{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: 0},
					],
					statementPerformer.where(this.indexesTable.nameTableColumn, name));
			index.queueTruncate(statementPerformer);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocuments(statementPerformer, name, keys, fullInfo) {
		// Setup
		let	internals = this.internals;

		// Get index
		let	[index, indexError] = await this.getForName(statementPerformer, name);
		if (indexError)
			// Error
			return [null, null, 'Unknown index: ' + name];

		// Get document type last revision
		let	documentTypeLastRevision = await internals.documents.getLastRevision(statementPerformer, index.type);

		// Check if up to date
		if (index.lastDocumentRevision == documentTypeLastRevision) {
			// Setup
			let	wheres = keys.map(key => statementPerformer.where(index.table.keyTableColumn, key));

			// Check for full info
			if (fullInfo) {
				// Documents
				let	[selectResults, documentsByID, resultsError] =
							await internals.documents.getDocuments(statementPerformer, index.type, index.table,
									internals.documents.getInnerJoinForDocument(statementPerformer, index.type,
											index.table.idTableColumn),
									wheres, null);
				
				// Handle results
				if (selectResults) {
					// Transmogrify results
					var	transmogrifiedResults = {};
					for (let i = 0; i < keys.length; i++) {
						// Massage results
						let	result = selectResults[i];

						if (result["count(*)"] == 1)
							// Key was found
							transmogrifiedResults[keys[i]] = documentsByID[result.id];
					}

					return [true, transmogrifiedResults, null];
				} else
					// Error
					return [null, null, resultsError];
			} else {
				// Document info
				let	[results, resultsError] =
						await internals.documents.getDocumentInfos(statementPerformer, index.type, index.table,
								internals.documents.getInnerJoinForDocumentInfo(statementPerformer, index.type,
										index.table.idTableColumn),
								wheres, null);
				
				// Handle results
				if (results) {
					// Transmogrify results
					var	transmogrifiedResults = {};
					for (let i = 0; i < keys.length; i++) {
						// Massage results
						let	result = results[i];
						if (result["count(*)"] == 1) {
							// Key was found
							let	info = {};
							info[result.documentID] = result.revision;
							transmogrifiedResults[keys[i]] = info;
						}
					}

					return [true, transmogrifiedResults, null];
				} else
					// Error
					return [null, null, resultsError];
			}
		} else if (documentTypeLastRevision) {
			// Update
			await this.updateIndex(statementPerformer, index);

			return [false, null, null];
		} else
			// No document of this type yet
			return [false, null, null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(statementPerformer, documentType) {
		// Catch errors
		try {
			// Select all Indexes for this document type
			let	results =
						await statementPerformer.select(true, this.indexesTable,
								statementPerformer.where(this.indexesTable.typeTableColumn, documentType));
			
			var	indexes = [];
			for (let result of results) {
				// Create Index and update stuffs
				let	index =
							new Index(statementPerformer, result.name, result.type,
									result.relevantProperties.split(','), this.keysSelectorInfo[result.keysSelector],
									JSON.parse(result.keysSelectorInfo.toString()), result.lastDocumentRevision);
				indexes.push(index);
			}

			return indexes;
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
			// Select all Indexes for this name
			let	results =
						await statementPerformer.select(true, this.indexesTable,
								statementPerformer.where(this.indexesTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Index
				let	result = results[0];
				let	index =
							new Index(statementPerformer, result.name, result.type,
									result.relevantProperties.split(','), this.keysSelectorInfo[result.keysSelector],
									JSON.parse(result.keysSelectorInfo.toString()), result.lastDocumentRevision);

				return [index, null];
			} else
				// Don't have
				return [null, 'No Index found with name ' + name];
		} catch(error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Indexes'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	update(statementPerformer, indexes, initialLastRevision, updateDocumentInfos) {
		// Iterate indexes
		for (let index of indexes) {
			// Update
			if (index.queueUpdates(statementPerformer, initialLastRevision, updateDocumentInfos)) {
				// Update table
				statementPerformer.queueUpdate(this.indexesTable,
						[{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn,
									value: index.lastDocumentRevision}],
									statementPerformer.where(this.indexesTable.nameTableColumn, index.name));
			}
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async updateIndex(statementPerformer, index) {
		// Setup
		let	internals = this.internals;
		let	documentUpdateTracker = internals.getDocumentUpdateTrackerForIndex(index);

		// Get update document infos
		let	updateDocumentInfos =
					await internals.documents.getUpdateDocumentInfos(statementPerformer, index.type,
							index.lastDocumentRevision, 150);
		documentUpdateTracker.addDocumentInfos(updateDocumentInfos);
		
		// Perform updates
		await statementPerformer.batchLockedForWrite(documentUpdateTracker.tables(),
				() => { return (async() => {
					// Finalize DocumentUpdateTracker
					documentUpdateTracker.finalize(statementPerformer, index.lastDocumentRevision);
				})()});
	}
}
