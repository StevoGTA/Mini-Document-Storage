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
	constructor(internals) {
		// Store
		this.internals = internals;

		// Setup
		let	statementPerformer = internals.statementPerformer;
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
	async register(info) {
		// Setup
		let	name = info.name;
		let	fromDocumentType = info.fromDocumentType;
		let	toDocumentType = info.toDocumentType;

		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		// Validate info
		if (!name || !fromDocumentType || !toDocumentType)
			return 'Missing required info';

		// Check if need to create Associations table
		await internals.createTableIfNeeded(this.associationsTable);

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
	async update(name, infos) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

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

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	async getAssociation(name) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

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
