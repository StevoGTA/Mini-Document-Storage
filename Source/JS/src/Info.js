//
//  Info.js
//
//  Created by Stevo on 2/3/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// Info
module.exports = class Info {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals) {
		// Store
		this.internals = internals;

		// Setup
		let	statementPerformer = internals.statementPerformer;
		let	TableColumn = statementPerformer.tableColumn();
		this.table =
				statementPerformer.table('Info',
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
	async get(keys) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(this.table,
								[this.table.keyTableColumn, this.table.valueTableColumn],
								statementPerformer.where(this.table.keyTableColumn, keys));

			// Iterate results
			var	info = {};
			for (let result of results)
				// Update stuffs
				info[result.key] = result.value;

			return info;
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return {};
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async set(info) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = this.internals.statementPerformer;

		// Check if need to create table
		await internals.createTableIfNeeded(this.table);

		// Iterate info
		for (let [key, value] of Object.entries(info))
			// Add statement for this entry
			statementPerformer.queueReplace(this.table,
					[
						{tableColumn: this.table.keyTableColumn, value: key},
						{tableColumn: this.table.valueTableColumn, value: value},
					]);
	}
};
