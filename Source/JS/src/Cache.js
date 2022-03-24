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
	constructor(statementPerformer, name, relevantProperties, valuesInfos, lastDocumentRevision) {
		// Store
		this.statementPerformer = statementPerformer;

		this.name = name;
		this.relevantProperties = new Set(relevantProperties);
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
									valuesInfos.map(valuesInfo => {
											// // Check value type
											// if (valuesInfo.valueType == 'integer')
												// Integer
												return new TableColumn.INT(valuesInfo.name,
														TableColumn.options.nonNull | TableColumn.options.unsigned);
											}));
		this.table = statementPerformer.table(tableName, tableColumns);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	queueCreate() { this.statementPerformer.queueCreateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueTruncate() { this.statementPerformer.queueTruncateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueUpdates(initialLastRevision, updateDocumentInfos) {
		// Check last revision
		if (initialLastRevision == this.lastDocumentRevision) {
			// Iterate update document infos
			for (let updateDocumentInfo of updateDocumentInfos) {
				// Check if json overlaps with the relevant properties
				if (Object.keys(updateDocumentInfos.json).find(property => this.relevantProperties.has(property))) {
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
						for (let info of cache.info) {
							// Query value
							let	value = info.selector(updateDocumentInfo.json, info);

							// Add info
							tableColumns.push({tableColumn: this.table.tableColumn(info.name), value: value});
						}

						// Queue
						this.statementPerformer.queueReplace(this.table, tableColumns);
					} else
						// Not active
						this.statementPerformer.queueDelete(this.table,
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
