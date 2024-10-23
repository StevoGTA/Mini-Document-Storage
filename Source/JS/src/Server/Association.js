//
//  Association.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// Association
module.exports = class Association {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer, name, fromType, toType) {
		// Store
		this.fromType = fromType;
		this.toType = toType;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		let	tableName = 'Association-' + name;
		this.table =
				statementPerformer.table(tableName,
						[
							new TableColumn.INT('fromID', TableColumn.options.nonNull | TableColumn.options.unsigned),
							new TableColumn.INT('toID', TableColumn.options.nonNull | TableColumn.options.unsigned),
						]);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	tableColumn(name) { return this.table.tableColumn(name); }

	//------------------------------------------------------------------------------------------------------------------
	create(statementPerformer) { statementPerformer.queueCreateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	update(statementPerformer, action, fromID, toID) {
		// Check action
		if (action == "add")
			// Add
			statementPerformer.queueInsertInto(this.table,
					[
						{tableColumn: this.table.fromIDTableColumn, value: fromID},
						{tableColumn: this.table.toIDTableColumn, value: toID},
					]);
		else
			// Remove
			statementPerformer.queueDelete(this.table,
					statementPerformer.where(
							[
								{tableColumn: this.table.fromIDTableColumn, value: fromID},
								{tableColumn: this.table.toIDTableColumn, value: toID},
							]));
	
	}
};
