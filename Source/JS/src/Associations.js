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
			let	association = Association(statementPerformer, name);
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
}
