//
//  Collection.js
//
//  Created by Stevo on 2/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// Collection
module.exports = class Collection {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(statementPerformer, name, type, relevantProperties, isIncludedSelector, isIncludedSelectorInfo,
			lastDocumentRevision) {
		// Store
		this.name = name;
		this.type = type;
		this.relevantProperties = relevantProperties;
		this.isIncludedSelector = isIncludedSelector;
		this.isIncludedSelectorInfo = isIncludedSelectorInfo;
		this.lastDocumentRevision = lastDocumentRevision;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		let	tableName = 'Collection-' + name;
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
	queueCreate(statementPerformer) { statementPerformer.queueCreateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueTruncate(statementPerformer) { statementPerformer.queueTruncateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueUpdates(statementPerformer, initialLastRevision, updateDocumentInfos) {
		// Check last revision
		if (initialLastRevision == this.lastDocumentRevision) {
			// Setup
			var	notIncludedIDs = [];

			// Iterate update document infos
			for (let updateDocumentInfo of updateDocumentInfos) {
				// Check if json overlaps with the relevant properties
				if (Object.keys(updateDocumentInfo.json).find(property => this.relevantProperties.includes(property))) {
					// Check active
					if (updateDocumentInfo.active) {
						// Call includedFunction for info
						let	isIncluded = this.isIncludedSelector(updateDocumentInfo.json, this.isIncludedSelectorInfo);

						// Check results
						if (isIncluded) {
							// Included
							if (updateDocumentInfo.id)
								// Use id
								statementPerformer.queueReplace(this.table,
										[{tableColumn: this.table.idTableColumn, value: updateDocumentInfo.id}]);
							else
								// Use idVariable
								statementPerformer.queueReplace(this.table,
										[{tableColumn: this.table.idTableColumn,
												variable: updateDocumentInfo.idVariable}]);
						} else if (updateDocumentInfo.id)
							// Not included
							notIncludedIDs.push(updateDocumentInfo.id);
					} else
						// Not active
						notIncludedIDs.push(updateDocumentInfo.id);
				}

				// Update
				this.lastDocumentRevision = updateDocumentInfo.revision;
			}

			// Check if have any not included IDs
			if (notIncludedIDs.length > 0)
				// Queue deleted
				statementPerformer.queueDelete(this.table,
						statementPerformer.where(this.table.idTableColumn, notIncludedIDs));

			return true;
		} else
			// Too out of date
			return false;
	}
};
