//
//  Index.js
//
//  Created by Stevo on 2/22/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// Index
module.exports = class Index {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer, name, type, relevantProperties, keysSelector, keysSelectorInfo,
			lastDocumentRevision) {
		// Store
		this.name = name;
		this.type = type;
		this.relevantProperties = relevantProperties;
		this.keysSelector = keysSelector;
		this.keysSelectorInfo = keysSelectorInfo;
		this.lastDocumentRevision = lastDocumentRevision;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		let	tableName = 'Index-' + name;
		this.table =
				statementPerformer.table(tableName,
						[
							new TableColumn.VARCHAR('key',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									767),
							new TableColumn.INT('id',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unsigned,
									tableName),
							]);
	}

	// Instance methods
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
					// Check if have existing id
					if (updateDocumentInfo.id)
						// Delete existing entries
						statementPerformer.queueDelete(this.table,
								statementPerformer.where(this.table.idTableColumn, updateDocumentInfo.id));

					// Check if active
					if (updateDocumentInfo.active) {
						// Get updated info
						let	keys = this.keysSelector(updateDocumentInfo.json, this.keysSelectorInfo);

						// Queue changes
						for (let key of keys) {
							// Queue this change
							if (updateDocumentInfo.id)
								// Use id
								statementPerformer.queueInsertInto(this.table,
										[
											{tableColumn: this.table.keyTableColumn, value: key},
											{tableColumn: this.table.idTableColumn, value: updateDocumentInfo.id},
										]);
							else
								// Use idVariable
								statementPerformer.queueInsertInto(this.table,
										[
											{tableColumn: this.table.keyTableColumn, value: key},
											{tableColumn: this.table.idTableColumn,
													variable: updateDocumentInfo.idVariable},
										]);
						}
					}
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
