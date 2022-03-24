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
	constructor(statementPerformer, name, relevantProperties, isIncludedSelector, isIncludedSelectorInfo,
			lastDocumentRevision) {
		// Store
		this.statementPerformer = statementPerformer;

		this.name = name;
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
	queueCreate() { this.statementPerformer.queueCreateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueTruncate() { this.statementPerformer.queueTruncateTable(this.table); }

	//------------------------------------------------------------------------------------------------------------------
	queueUpdates(initialLastRevision, updateDocumentInfos) {
		// Check last revision
		if (initialLastRevision == this.lastDocumentRevision) {
			// Setup
			var	notIncludedIDs = [];

			// Iterate update document infos
			for (let updateDocumentInfo of updateDocumentInfos) {
				// Check if json overlaps with the relevant properties
				if (Object.keys(updateDocumentInfos.json).find(property => this.relevantProperties.has(property))) {
					// Check active
					if (document.active) {
						// Call includedFunction for info
						let	isIncluded = this.isIncludedSelector(updateDocumentInfo.json, this.isIncludedSelectorInfo);

						// Check results
						if (isIncluded) {
							// Included
							if (document.id)
								// Use id
								this.statementPerformer.queueReplace(this.table,
										[{tableColumn: this.table.idTableColumn, value: document.id}]);
							else
								// Use idVariable
								this.statementPerformer.queueReplace(this.table,
										[{tableColumn: this.table.idTableColumn, variable: document.idVariable}]);
						} else if (document.id)
							// Not included
							notIncludedIDs.push(document.id);
					} else
						// Not active
						notIncludedIDs.push(document.id);
				}

				// Update
				this.lastDocumentRevision = updateDocumentInfo.revision;
			}

			// Queue changes
			if (notIncludedIDs.length > 0)
				// Queue deleted
				this.statementPerformer.queueDelete(this.table,
						this.statementPerformer.where(this.table.idTableColumn, notIncludedIDs));

			return true;
		} else
			// Too out of date
			return false;
	}
};
