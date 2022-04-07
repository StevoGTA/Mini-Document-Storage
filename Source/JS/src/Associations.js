//
//  Associations.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	Association = require('./Association');

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

		// Check if need to create Associations table
		await internals.createTableIfNeeded(statementPerformer, this.associationsTable);

		// Try to retrieve current entry
		var	results =
					await statementPerformer.select(this.associationsTable,
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
			association.create(internals);
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
		let	[association, associationError] = await this.getAssociation(name);
		if (associationError)
			// Error
			return associationError;
		
		// Get from document info
		let	[fromDocumentInfo, fromDocumentInfoError] =
					await internals.documents.getIDsForDocumentIDs(association.fromType, [...fromDocumentIDs]);
		if (fromDocumentInfoError)
			// Error
			return fromDocumentInfoError;
		
		// Get to document info
		let	[toDocumentInfo, toDocumentInfoError] =
					await internals.documents.getIDsForDocumentIDs(association.toType, [...toDocumentIDs]);
		if (toDocumentInfoError)
			// Error
			return toDocumentInfoError;
		
		// Update
		await statementPerformer.batch(
				() =>
						{
							// Iterate infos
							for (let info of infos) {
								// Setup
								let	action = info.action;
								let	fromID = fromDocumentInfo[info.fromID];
								let	toID = toDocumentInfo[info.toID];

								// Update
								association.update(action, fromID, toID);
							}
						});
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocumentInfos(statementPerformer, name, fromDocumentID, toDocumentID, startIndex, documentCount,
			fullInfo) {
		// Validate
		if ((!fromDocumentID && !toDocumentID) || (fromDocumentID && toDocumentID))
			return [null, null, 'Must specify one of fromDocumentID or toDocumentID'];

		// Setup
		let	internals = this.internals;

		// Get association
		let	[association, associationError] = await this.getAssociation(name);
		if (associationError)
			// Error
			return [null, null, associationError];
		

		// Compose where
		let	documentType = fromDocumentID ? association.fromType : association.toType;
		let	idTableColumn = fromDocumentID ? association.table.fromIDTableColumn : association.table.toIDTableColumn;
		let	documentID = fromDocumentID ? fromDocumentID : toDocumentID;
		let	[documentInfo, documentInfoError] = await internals.getIDsForDocumentIDs(documentType, [documentID]);
		if (documentInfoError)
			return [null, null, documentInfoError];
		
		let	where = statementPerformer.where(idTableColumn, documentInfo[documentID]);

		// Query count
		let	totalCount = await statementPerformer.count(association.table, where);

		// Check for full info
		var	results, resultsError;
		if (fullInfo == 0) {
			// Document info
			[results, resultsError] =
					await internals.documents.getDocumentInfos(documentType, association.table,
							internals.documents.getDocumentInfoInnerJoin(documentType, idTableColumn),
							where, statementPerformer.limit(startIndex + ',' + documentCount));
		} else
			// Documents
			[results, resultsError] =
					await internals.documents.getDocuments(documentType, association.table,
							internals.documents.getDocumentInnerJoin(documentType, idTableColumn),
							where, statementPerformer.limit(startIndex + ',' + documentCount));
		if (resultsError)
			return [null, null, resultsError];
		
		return [totalCount, results, null];
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async getAssociation(statementPerformer, name) {
		// Catch errors
		try {
			// Retrieve association
			let	results =
						await statementPerformer.select(this.associationsTable,
								statementPerformer.where(this.associationsTable.nameTableColumn, name));
			if (results.length > 0)
				// Success
				return [new Association(statementPerformer, name, results[0].fromType, results[0].toType), null];
			else
				// Error
				return [null, 'No association found with name ' + name];
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
