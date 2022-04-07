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

	// Properties
	indexInfo = {};

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

		let	isUpToDate = info.isUpToDate;
		if (!isUpToDate)
			return 'Missing isUpToDate';

		let	keysSelector = info.keysSelector;
		if (!keysSelector)
			return 'Missing keysSelector';

		let	keysSelectorInfo = info.keysSelectorInfo;
		if (!keysSelectorInfo)
			return 'Missing keysSelectorInfo';

		// Setup
		let	internals = this.internals;

		// Check if need to create Indexes table
		await internals.createTableIfNeeded(statementPerformer, this.indexesTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(this.indexesTable,
							[
								this.indexesTable.keysSelectorTableColumn,
								this.indexesTable.keysSelectorInfoTableColumn,
								this.indexesTable.lastDocumentRevisionTableColumn,
							],
							statementPerformer.where(this.indexesTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			let	index =
						new Index(statementPerformer, name, relevantProperties, this.keysSelectorInfo[keysSelector],
								keysSelectorInfo, 0);
			this.indexInfo[name] = index;

			statementPerformer.queueInsertInto(this.indexesTable,
					[
						{tableColumn: this.indexesTable.nameTableColumn, value: name},
						{tableColumn: this.indexesTable.typeTableColumn, value: documentType},
						{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
						{tableColumn: this.indexesTable.keysSelectorInfoTableColumn, value: keysSelectorInfo},
						{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: 0},
				]);
			index.queueCreate();
		} else if (keysSelector != results[0].keysSelector) {
			// Update to new keysSelector
			let	index =
						new Index(statementPerformer, name, relevantProperties, this.keysSelectorInfo[keysSelector],
								keysSelectorInfo, 0);
			this.indexInfo[name] = index;

			statementPerformer.queueUpdate(this.indexesTable,
					[
						{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
								value: relevantProperties.toString()},
						{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
						{tableColumn: this.indexesTable.keysSelectorInfoTableColumn, value: keysSelectorInfo},
						{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: 0},
					],
					statementPerformer.where(this.indexesTable.nameTableColumn, name));
			index.queueTruncate();
		} else if (!util.isDeepStrictEqual(keysSelectorInfo, JSON.parse(results[0].keysSelectorInfo))) {
			// keysSelectorInfo has changed
			if (isUpToDate) {
				// Updated info needed for future document changes
				let	index =
							new Index(statementPerformer, name, relevantProperties, keysSelector, keysSelectorInfo,
									results[0].lastDocumentRevision);
				this.indexInfo[name] = index;

				statementPerformer.queueUpdate(this.indexesTable,
						[{tableColumn: this.indexesTable.keysSelectorInfoTableColumn, value: keysSelectorInfo}],
						statementPerformer.where(this.indexesTable.nameTableColumn, name));
			} else {
				// Need to rebuild this index
				let	index =
						new Index(statementPerformer, name, relevantProperties, this.keysSelectorInfo[keysSelector],
								keysSelectorInfo, 0);
				this.indexInfo[name] = index;

				statementPerformer.queueUpdate(this.indexesTable,
						[
							{tableColumn: this.indexesTable.relevantPropertiesTableColumn,
									value: relevantProperties.toString()},
							{tableColumn: this.indexesTable.keysSelectorTableColumn, value: keysSelector},
							{tableColumn: this.indexesTable.keysSelectorInfoTableColumn, value: keysSelectorInfo},
							{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn, value: 0},
						],
						statementPerformer.where(this.indexesTable.nameTableColumn, name));
				index.queueTruncate();
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentType(statementPerformer, documentType) {
		// Catch errors
		try {
			// Select all Indexes for this document type
			let	results =
						await statementPerformer.select(this.indexesTable,
								statementPerformer.where(this.indexesTable.typeTableColumn, documentType));
			
			var	indexes = [];
			for (let result of results) {
				// Create Index and update stuffs
				let	index =
							new Index(statementPerformer, result.name, result.relevantProperties,
									this.keysSelectorInfo[result.keysSelector], result.keysSelectorInfo,
									result.lastDocumentRevision);
				indexes.push(index);
				this.indexInfo[result.name] = index;
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
		// Check if already have
		var	index = this.indexInfo[name];
		if (index)
			// Have
			return index;

		// Catch errors
		try {
			// Select all Indexes for this document type
			let	results =
						await statementPerformer.select(this.indexesTable,
								statementPerformer.where(this.indexesTable.nameTableColumn, name));
			
			// Handle results
			if (results.length > 0) {
				// Have Index
				let	result = results[0];
				index =
						new Index(statementPerformer, result.name, result.relevantProperties,
								this.keysSelectorInfo[result.keysSelector], result.keysSelectorInfo,
								result.lastDocumentRevision);
				this.indexInfo[name] = index;

				return index;
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
	update(statementPerformer, indexes, initialLastRevision, updateDocumentInfos) {
		// Iterate indexes
		for (let index of indexes) {
			// Update
			if (index.queueUpdates(initialLastRevision, updateDocumentInfos)) {
				// Update table
				statementPerformer.queueUpdate(this.indexesTable,
						[{tableColumn: this.indexesTable.lastDocumentRevisionTableColumn,
									value: index.lastDocumentRevision}],
									statementPerformer.where(this.indexesTable.nameTableColumn, index.name));
			}
		}
	}
}
