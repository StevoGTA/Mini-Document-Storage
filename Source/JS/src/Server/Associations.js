//
//  Associations.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Association = require('./Association');
let	Caches = require('./Caches');

//----------------------------------------------------------------------------------------------------------------------
// Associations
module.exports = class Associations {

	// Properties
	associationInfo = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, statementPerformer) {
		// Store
		this.internals = internals;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		this.associationsTable =
				statementPerformer.table('Associations',
						[
							new TableColumn.VARCHAR('name',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									100),
							new TableColumn.VARCHAR('fromType', TableColumn.options.nonNull, 45),
							new TableColumn.VARCHAR('toType', TableColumn.options.nonNull, 45),
						]);
	}

	//------------------------------------------------------------------------------------------------------------------
	async register(statementPerformer, info) {
		// Validate
		if (!info || (typeof info != 'object'))
			return 'Missing info';

		let	name = info.name;
		if (!name)
			return 'Missing name';
		
		let	fromDocumentType = info.fromDocumentType;
		if (!fromDocumentType)
			return 'Missing fromDocumentType';

		let	toDocumentType = info.toDocumentType;
		if (!toDocumentType)
			return 'Missing toDocumentType';

		// Setup
		let	internals = this.internals;

		// Validate document types
		var	lastDocumentRevision = await internals.documents.getLastRevision(statementPerformer, fromDocumentType);
		if (lastDocumentRevision == null)
			return 'Unknown documentType: ' + fromDocumentType;

		lastDocumentRevision = await internals.documents.getLastRevision(statementPerformer, toDocumentType);
		if (lastDocumentRevision == null)
			return 'Unknown documentType: ' + toDocumentType;

		// Check if need to create Associations table
		await internals.createTableIfNeeded(statementPerformer, this.associationsTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(true, this.associationsTable,
							statementPerformer.where(this.associationsTable.nameTableColumn, name));
		if (results.length == 0) {
			// Add
			let	association = new Association(statementPerformer, name, fromDocumentType, toDocumentType);
			this.associationInfo[name] = association;

			statementPerformer.queueInsertInto(this.associationsTable,
					[
						{tableColumn: this.associationsTable.nameTableColumn, value: name},
						{tableColumn: this.associationsTable.fromTypeTableColumn, value: fromDocumentType},
						{tableColumn: this.associationsTable.toTypeTableColumn, value: toDocumentType},
					]);
			association.create(statementPerformer);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async update(statementPerformer, name, infos) {
		// Validate
		let	fromDocumentIDs = new Set();
		let	toDocumentIDs = new Set();
		for (let info of infos) {
			// Get info
			let	action = info.action;
			let	fromID = info.fromID;
			let	toID = info.toID;

			// Check info
			if (!action)
				// Missing action
				return 'Missing action';
			else if ((action != 'add') && (action != 'remove'))
				// Invalid action
				return 'Invalid action: ' + action;
			else if (!fromID)
				// Missing fromID
				return 'Missing fromID';
			else if (!toID)
				// Missing toID
				return 'Missing toID';
			
			// Update
			fromDocumentIDs.add(fromID);
			toDocumentIDs.add(toID);
		}

		// Setup
		let	internals = this.internals;

		// Get association
		let	[association, associationError] = await this.getForName(statementPerformer, name);
		if (associationError)
			// Error
			return associationError;
		
		// Get from document info
		let	[fromDocumentInfo, fromDocumentInfoError] =
					await internals.documents.getIDsForDocumentIDs(statementPerformer, association.fromType,
							[...fromDocumentIDs]);
		if (fromDocumentInfoError)
			// Error
			return fromDocumentInfoError;
		
		// Get to document info
		let	[toDocumentInfo, toDocumentInfoError] =
					await internals.documents.getIDsForDocumentIDs(statementPerformer, association.toType,
							[...toDocumentIDs]);
		if (toDocumentInfoError)
			// Error
			return toDocumentInfoError;
		
		// Update
		await statementPerformer.batch(true,
				() =>
						{
							// Iterate infos
							for (let info of infos) {
								// Setup
								let	action = info.action;
								let	fromID = fromDocumentInfo[info.fromID];
								let	toID = toDocumentInfo[info.toID];

								// Update
								association.update(statementPerformer, action, fromID, toID);
							}
						});
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocuments(statementPerformer, name, fromDocumentID, toDocumentID, startIndex, count, fullInfo) {
		// Setup
		let	internals = this.internals;

		// Get association
		let	[association, associationError] = await this.getForName(statementPerformer, name);
		if (associationError)
			// Error
			return [null, null, associationError];

		// Check approach
		if (fromDocumentID || toDocumentID) {
			// "From" or "To"
			// Compose where
			let	sourceDocumentType = fromDocumentID ? association.fromType : association.toType;
			let	returnDocumentType = fromDocumentID ? association.toType : association.fromType;

			let	innerJoinIDTableColumn =
						fromDocumentID ? association.table.toIDTableColumn : association.table.fromIDTableColumn;
			let	whereIDTableColumn =
						fromDocumentID ? association.table.fromIDTableColumn : association.table.toIDTableColumn;
			let	documentID = fromDocumentID ? fromDocumentID : toDocumentID;
			let	[ids, idsError] =
						await internals.documents.getIDsForDocumentIDs(statementPerformer, sourceDocumentType,
								[documentID]);
			if (idsError)
				return [null, null, idsError];
			
			let	where = statementPerformer.where(whereIDTableColumn, ids[documentID]);

			// Query count
			let	totalCount = await statementPerformer.count(association.table, where);

			// Check for full info
			if (fullInfo) {
				// Documents
				let	[selectResults, documentsByID, resultsError] =
							await internals.documents.getDocuments(statementPerformer, returnDocumentType,
									association.table,
									internals.documents.getInnerJoinForDocument(statementPerformer, returnDocumentType,
											innerJoinIDTableColumn),
									where, statementPerformer.limit(startIndex, count));
				if (documentsByID)
					// Success
					return [totalCount, Object.values(documentsByID), null];
				else
					// Error
					return [null, null, resultsError];
			} else {
				// Document info
				let	[results, resultsError] =
							await internals.documents.getDocumentInfos(statementPerformer, returnDocumentType,
									association.table,
									internals.documents.getInnerJoinForDocumentInfo(statementPerformer,
											returnDocumentType, innerJoinIDTableColumn),
									where, statementPerformer.limit(startIndex, count));
				if (results)
					// Success
					return [totalCount,
							results.map(result =>
									{ return {documentID: result.documentID, revision: result.revision}; }),
							null];
				else
					// Error
					return [null, null, resultsError];
			}
		} else {
			// Return associations translated from DB IDs to Document IDs
			let	totalCount = await statementPerformer.count(association.table);

			// Select
			let	fromDocumentIDString =
						internals.documents.getDocumentIDTableColumnString(statementPerformer, association.fromType,
								'fromDocumentID');
			let	toDocumentIDString =
						internals.documents.getDocumentIDTableColumnString(statementPerformer, association.toType,
								'toDocumentID');

			let	results =
						await statementPerformer.select(true, association.table,
								fromDocumentIDString + ', ' + toDocumentIDString,
								internals.documents.getInnerJoinForDocumentInfos(statementPerformer,
										association.fromType, association.table.fromIDTableColumn,
										association.toType, association.table.toIDTableColumn));
			
			if (results)
				// Success
				return [totalCount, results, null];
			else
				// Error
				return [null, null, "Something went wrong..."];
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getValue(statementPerformer, name, action, fromDocumentIDs, cacheName, cachedValueNames) {
		// Validate
		if (!name)
			return [null, null, 'Missing name'];

		if (!action)
			return [null, null, 'Missing action'];
		if (action != 'sum')
			return [null, null, 'Invalid action'];

		if (!fromDocumentIDs)
			return [null, null, 'Missing fromDocumentIDs'];
		if (!Array.isArray(fromDocumentIDs))
			return [null, null, 'fromDocumentIDs is not an array'];
		if (fromDocumentIDs.length == 0)
			return [null, null, 'Missing fromDocumentID']

		if (!cacheName)
			return [null, null, 'Missing cacheName'];

		if (!cachedValueNames)
			return [null, null, 'Missing cachedValueNames'];
		if (!Array.isArray(cachedValueNames))
			return [null, null, 'cachedValueNames is not an array.'];
		if (cachedValueNames.length == 0)
			return [null, null, "Missing cachedValueName"];

		// Setup
		let	internals = this.internals;
		
		// Get association
		let	[association, associationError] = await this.getForName(statementPerformer, name);
		if (associationError)
			// Error
			return [null, null, associationError];
		
		// Get cache
		let	[cache, cacheError] = await internals.caches.getForName(statementPerformer, cacheName);
		if (cacheError)
			// Error
			return [null, null, cacheError];
		
		// Get TableColumns
		var	tableColumns = [];
		for (let cachedValueName of cachedValueNames) {
			// Get TableColumn
			let	tableColumn = cache.tableColumn(cachedValueName);
			if (!tableColumn)
				// Unknown cache valueName
				return [null, null, 'Unknown cache valueName: ' + cachedValueName];
			
			// Add to array
			tableColumns.push(tableColumn);
		}
		
		// Get document type last revision
		let	documentTypeLastRevision = await internals.documents.getLastRevision(statementPerformer, cache.type);

		// Check if up to date
		if (cache.lastDocumentRevision == documentTypeLastRevision) {
			// Get from document info
			let	[ids, idsError] =
						await internals.documents.getIDsForDocumentIDs(statementPerformer, association.fromType,
								fromDocumentIDs);
			if (idsError)
				return [null, null, idsError];

			var	fromIDs = [];
			for (let fromDocumentID of fromDocumentIDs) {
				// Get id
				let	id = ids[fromDocumentID];
				if (id)
					// Have id
					fromIDs.push(id);
				else
					// fromDocumentID not found
					return [null, null, 'Document ' + fromDocumentID + ' not found.'];
			}

			// Perform
			var	mySQLResults =
						await statementPerformer.sum(association.table, tableColumns,
								statementPerformer.innerJoin(cache.table, association.table.toIDTableColumn,
										cache.table.idTableColumn),
								statementPerformer.where(association.table.fromIDTableColumn, fromIDs));

			// Process results
			for (let cachedValueName of cachedValueNames)
				// Update if necessary
				mySQLResults[cachedValueName] = mySQLResults[cachedValueName] || 0;

			return [true, mySQLResults, null];
		} else if (documentTypeLastRevision) {
			// Update
			await internals.caches.updateCache(statementPerformer, cache);

			return [false, null, null];
		} else 
			// No document of this type yet
			return [false, null, null];
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async getForName(statementPerformer, name) {
		// Check if already have
		var	association = this.associationInfo[name];
		if (association)
			// Have
			return [association, null];

		// Catch errors
		try {
			// Retrieve association
			let	results =
						await statementPerformer.select(true, this.associationsTable,
								statementPerformer.where(this.associationsTable.nameTableColumn, name));
			if (results.length > 0) {
				// Success
				let	result = results[0];
				association = new Association(statementPerformer, name, result.fromType, result.toType);
				this.associationInfo[name] = association;

				return [association, null];
			} else
				// Error
				return [null, 'Unknown association: ' + name];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Associations'];
			else
				// Other error
				throw error;
		}
	}
}
