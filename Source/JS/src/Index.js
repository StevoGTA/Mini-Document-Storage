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
	constructor(statementPerformer, name, relevantProperties, keysSelector, keysSelectorInfo, lastDocumentRevision) {
		// Store
		this.statementPerformer = statementPerformer;

		this.name = name;
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
							new TableColumn.INT('id',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unsigned,
									tableName),
							]);
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
					// Check if have existing id
					if (updateDocumentInfos.id)
						// Delete existing entries
						this.statementPerformer.queueDelete(this.table,
								this.statementPerformer.where(this.table.idTableColumn, updateDocumentInfos.id));

					// Check if active
					if (updateDocumentInfo.active) {
						// Get updated info
						let	keys = this.keysSelector(updateDocumentInfo.json, this.keysSelectorInfo);

						// Queue changes
						for (let key of keys) {
							// Queue this change
							if (updateDocumentInfo.id)
								// Use id
								this.statementPerformer.queueInsertInto(this.table,
										[
											{tableColumn: this.table.keyTableColumn, value: key},
											{tableColumn: this.table.idTableColumn, value: updateDocumentInfo.id},
										]);
							else
								// Use idVariable
								this.statementPerformer.queueInsertInto(this.table,
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
