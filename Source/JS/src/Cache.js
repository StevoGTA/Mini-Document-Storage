//
//  Cache.js
//
//  Created by Stevo on 2/15/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// Cache
module.exports = class Cache {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer, name, type, relevantProperties, valuesInfos, lastDocumentRevision) {
		// Store
		this.name = name;
		this.type = type;
		this.relevantProperties = relevantProperties;
		this.valuesInfos = valuesInfos;
		this.lastDocumentRevision = lastDocumentRevision;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		let	tableName = 'Cache-' + name;
		let	tableColumns =
					[new TableColumn.INT('id',
							TableColumn.options.primaryKey | TableColumn.options.nonNull | TableColumn.options.unsigned,
							tableName)]
							.concat(
									valuesInfos.map(valueInfo => {
											// // Check value type
											// if (valueInfo.valueType == 'integer')
												// Integer
												return new TableColumn.INT(valueInfo.name,
														TableColumn.options.nonNull | TableColumn.options.unsigned);
											}));
		this.table = statementPerformer.table(tableName, tableColumns);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	tableColumn(name) { return this.table.tableColumn(name); }

	//------------------------------------------------------------------------------------------------------------------
	queueCreate(statementPerformer) { statementPerformer.queueCreateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueTruncate(statementPerformer) { statementPerformer.queueTruncateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueUpdates(statementPerformer, initialLastRevision, updateDocumentInfos) {
		// Check last revision
		if (initialLastRevision == this.lastDocumentRevision) {
			// Iterate update document infos
			for (let updateDocumentInfo of updateDocumentInfos) {
				// Check if json overlaps with the relevant properties
				if (Object.keys(updateDocumentInfo.json).find(property => this.relevantProperties.includes(property))) {
					// Check active
					if (updateDocumentInfo.active) {
						// Active
						var	tableColumns = [];
						if (updateDocumentInfo.id)
							// Use id
							tableColumns.push({tableColumn: this.table.idTableColumn, value: updateDocumentInfo.id});
						else
							// Use idVariable
							tableColumns.push(
									{tableColumn: this.table.idTableColumn, variable: updateDocumentInfo.idVariable});

						// Iterate infos
						for (let valueInfo of this.valuesInfos) {
							// Query value
							let	value = valueInfo.selector(updateDocumentInfo.json, valueInfo.name);

							// Add info
							tableColumns.push({tableColumn: this.table.tableColumn(valueInfo.name), value: value});
						}

						// Queue
						statementPerformer.queueReplace(this.table, tableColumns);
					} else
						// Not active
						statementPerformer.queueDelete(this.table,
								[{tableColumn: this.table.idTableColumn, value: updateDocumentInfo.id}]);
				}

				// Update
				this.lastDocumentRevision = updateDocumentInfo.revision;
			}

			return true;
		} else
			// Too out of date
			return false;
	}
};
