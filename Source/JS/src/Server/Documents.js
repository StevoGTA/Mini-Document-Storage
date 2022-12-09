//
//  Documents.js
//
//  Created by Stevo on 3/1/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	uuid = require('uuid');
let	{UuidTool} = require('uuid-tool');

//----------------------------------------------------------------------------------------------------------------------
// Documents
module.exports = class Documents {

	// Properties
	tablesInfoInfo = {};

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(internals, statementPerformer) {
		// Store
		this.internals = internals;

		// Setup
		let	TableColumn = statementPerformer.tableColumn();
		this.documentsTable =
				statementPerformer.table('Documents',
						[
							new TableColumn.VARCHAR('type',
									TableColumn.options.primaryKey | TableColumn.options.nonNull |
											TableColumn.options.unique,
									45),
							new TableColumn.INT('lastRevision',
									TableColumn.options.nonNull | TableColumn.options.unsigned),
						]);
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async create(statementPerformer, documentType, infos) {
		// Validate
		if (!infos || !Array.isArray(infos) || (infos.length == 0))
			return [null, 'Missing info(s)'];

		for (let info of infos) {
			// Setup
			let	documentID = info.documentID;
			if (documentID && (documentID.length > 22))
				return [null, 'Invalid documentID: ' + documentID + ' (exceeds max length of 22)'];

			let	json = info.json;
			if (!json)
				return [null, 'Missing info json'];
		}
	
		// Setup
		let	internals = this.internals;

		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Create tables if needed
		await internals.createTableIfNeeded(statementPerformer, this.documentsTable);
		await internals.createTableIfNeeded(statementPerformer, tablesInfo.infoTable);
		await internals.createTableIfNeeded(statementPerformer, tablesInfo.contentTable);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(statementPerformer, documentType);

		// Perform with tables locked
		let	tables =
					[this.documentsTable, tablesInfo.infoTable, tablesInfo.contentTable]
							.concat(documentUpdateTracker.tables());
		let	results =
					await statementPerformer.batchLockedForWrite(tables,
							() => { return (async() => {
								// Setup
								let	initialLastRevision = await this.getLastRevision(statementPerformer, documentType);
								var	lastRevision = initialLastRevision;
								var	returnDocumentInfos = [];

								// Iterate infos and queue statements
								for (let info of infos) {
									// Setup
									let	now = new Date().toISOString();
									let documentID = info.documentID || this.newID();
									let	creationDate = info.creationDate || now;
									let	modificationDate = info.modificationDate || now;
									let	revision = lastRevision + 1;
									let	json = info.json;

									let	idVariableName = "@id" + revision;

									// Add document infos
									returnDocumentInfos.push(
											{
												documentID: documentID,
												creationDate: creationDate,
												modificationDate: modificationDate,
												revision: revision,
											});
									documentUpdateTracker.addDocumentInfo(
											{
												idVariable: idVariableName,
												revision: revision,
												active: true,
												json: json,
												updatedProperties: Object.keys(json),
											});

									// Queue
									statementPerformer.queueInsertInto(tablesInfo.infoTable,
											[
												{tableColumn: tablesInfo.infoTable.documentIDTableColumn,
														value: documentID},
												{tableColumn: tablesInfo.infoTable.revisionTableColumn,
														value: revision},
												{tableColumn: tablesInfo.infoTable.activeTableColumn, value: 1},
											]);
									statementPerformer.queueSet(idVariableName, 'LAST_INSERT_ID()');
									statementPerformer.queueInsertInto(tablesInfo.contentTable,
											[
												{tableColumn: tablesInfo.contentTable.idTableColumn,
														variable: idVariableName},
												{tableColumn: tablesInfo.contentTable.creationDateTableColumn,
														value: creationDate},
												{tableColumn: tablesInfo.contentTable.modificationDateTableColumn,
														value: modificationDate},
												{tableColumn: tablesInfo.contentTable.jsonTableColumn,
														value: JSON.stringify(json)},
											]);
									
									// Update
									lastRevision += 1;
								}
								this.queueUpdateLastRevision(statementPerformer, documentType, lastRevision);
								documentUpdateTracker.finalize(statementPerformer, initialLastRevision);

								return returnDocumentInfos;
							})()});
		
		return [results, null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getSinceRevision(statementPerformer, documentType, sinceRevision, count) {
		// Validate
		if (typeof(sinceRevision) != 'number')
			return [null, null, 'Missing revision'];
		if (sinceRevision < 0)
			return [null, null, 'Invalid revision: ' + sinceRevision];
		if ((count != null) && (count < 1))
			return [null, null, 'Invalid count: ' + count];

		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);
		let	where = statementPerformer.where(tablesInfo.infoTable.revisionTableColumn, '>', sinceRevision);

		// Count relevant documents
		var	totalCount;
		try {
			// Perform
			totalCount = await statementPerformer.count(tablesInfo.infoTable, where);

			// Quick check for no documents
			if (totalCount == 0)
				// Nothing to do
				return [0, [], null];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, null, 'Unknown documentType: ' + documentType];
			else
				// Other error
				throw error;
		}

		// Retrieve relevant documents
		var	ids = [];
		var	documentsByID = {};
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.infoTable,
								[
									tablesInfo.infoTable.idTableColumn,
									tablesInfo.infoTable.documentIDTableColumn,
									tablesInfo.infoTable.revisionTableColumn,
									tablesInfo.infoTable.activeTableColumn,
									tablesInfo.contentTable.creationDateTableColumn,
									tablesInfo.contentTable.modificationDateTableColumn,
									tablesInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(tablesInfo.contentTable,
										tablesInfo.contentTable.idTableColumn),
								where,
								statementPerformer.orderBy(tablesInfo.infoTable.revisionTableColumn),
								count ? statementPerformer.limit(null, count) : null);

			// Handle results
			for (let result of results) {
				// Update info
				ids.push(result.id);
				documentsByID[result.id] =
						{
							documentID: result.documentID,
							revision: result.revision,
							active: result.active,
							creationDate: result.creationDate,
							modificationDate: result.modificationDate,
							json: JSON.parse(result.json.toString()),
							attachments: {},
						};
			}
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [0, []];
			else
				// Other error
				throw error;
		}

		// Retrieve attachments
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.attachmentTable,
								[
									tablesInfo.attachmentTable.idTableColumn,
									tablesInfo.attachmentTable.attachmentIDTableColumn,
									tablesInfo.attachmentTable.revisionTableColumn,
									tablesInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(tablesInfo.attachmentTable.idTableColumn, ids));
			
			// Handle results
			for (let result of results)
				// Add attachment info
				documentsByID[result.id].attachments[result.attachmentID] =
						{revision: result.revision, info: JSON.parse(result.info.toString())};
		} catch (error) {
			// Check error
			if (!error.message.startsWith('ER_NO_SUCH_TABLE'))
				// Other error
				throw error;
		}

		return [totalCount, Object.values(documentsByID)];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getForDocumentIDs(statementPerformer, documentType, documentIDs) {
		// Validate
		if (documentIDs.length == 0)
			return [null, 'Missing id(s)'];

		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		var	ids = [];
		var	documentsByID = {};
		let	missingDocumentIDsSet = new Set(documentIDs);
		try {
			// Retrieve relevant documents
			let	results =
						await statementPerformer.select(true, tablesInfo.infoTable,
								[
									tablesInfo.infoTable.idTableColumn,
									tablesInfo.infoTable.documentIDTableColumn,
									tablesInfo.infoTable.revisionTableColumn,
									tablesInfo.infoTable.activeTableColumn,
									tablesInfo.contentTable.creationDateTableColumn,
									tablesInfo.contentTable.modificationDateTableColumn,
									tablesInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(tablesInfo.contentTable,
									tablesInfo.contentTable.idTableColumn),
								statementPerformer.where(tablesInfo.infoTable.documentIDTableColumn, documentIDs));

			// Compose results
			for (let result of results) {
				// Update info
				ids.push(result.id);
				documentsByID[result.id] =
						{
							documentID: result.documentID,
							revision: result.revision,
							active: result.active,
							creationDate: result.creationDate,
							modificationDate: result.modificationDate,
							json: JSON.parse(result.json.toString()),
							attachments: {},
						};
				missingDocumentIDsSet.delete(result.documentID);
			}

			// Validate results
			if (missingDocumentIDsSet.size > 0)
				// Not found
				return [null, 'Unknown documentID: ' + [...missingDocumentIDsSet][0]];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'Unknown documentType: ' + documentType];
			else
				// Other error
				throw error;
		}

		// Retrieve attachments
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.attachmentTable,
								[
									tablesInfo.attachmentTable.idTableColumn,
									tablesInfo.attachmentTable.attachmentIDTableColumn,
									tablesInfo.attachmentTable.revisionTableColumn,
									tablesInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(tablesInfo.attachmentTable.idTableColumn, ids));
			
			// Handle results
			for (let result of results)
				// Add attachment info
				documentsByID[result.id].attachments[result.attachmentID] =
						{revision: result.revision, info: JSON.parse(result.info.toString())};
		} catch (error) {
			// Check error
			if (!error.message.startsWith('ER_NO_SUCH_TABLE'))
				// Other error
				throw error;
		}

		return [Object.values(documentsByID), null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async update(statementPerformer, documentType, infos) {
		// Validate
		if (!infos || !Array.isArray(infos) || (infos.length == 0))
			return [null, 'Missing infos'];
		if (infos.find(info => !info.documentID) != null)
			return [null, 'Missing documentID'];

		// Setup
		let	internals = this.internals;

		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(statementPerformer, documentType);

		// Catch errors
		try {
			// Perform with tables locked
			let	tables =
						[this.documentsTable, tablesInfo.infoTable, tablesInfo.contentTable]
								.concat(documentUpdateTracker.tables());
			let	results =
						await statementPerformer.batchLockedForWrite(tables,
								() => { return (async() => {
									// Setup
									let	initialLastRevision =
												await this.getLastRevision(statementPerformer, documentType);

									// Retrieve current document info
									let	results =
												await statementPerformer.select(true, tablesInfo.infoTable,
														[
															tablesInfo.infoTable.idTableColumn,
															tablesInfo.infoTable.documentIDTableColumn,
															tablesInfo.infoTable.activeTableColumn,
															tablesInfo.contentTable.jsonTableColumn,
														],
														statementPerformer.innerJoin(tablesInfo.contentTable,
																tablesInfo.infoTable.idTableColumn),
														statementPerformer.where(
																tablesInfo.infoTable.documentIDTableColumn,
																Object.values(infos).map(info => info.documentID)));
									let	documentsByID =
												Object.fromEntries(results.map(result => [result.documentID, result]));

									// Setup
									var	lastRevision = initialLastRevision;
									var	returnDocumentInfos = [];

									// Iterate infos and queue statements
									for (let info of infos) {
										// Setup
										let	documentID = info.documentID;
										let	currentDocument = documentsByID[documentID];
										if (!currentDocument)
											return [null, 'Unknown documentID: ' + documentID];
										
										let	id = currentDocument.id;
										let	revision = lastRevision + 1;
										let	modificationDate = new Date().toISOString();

										let	updated = info.updated || {};
										let	removed = info.removed || [];
										let	active = (info.active != null) ? info.active : currentDocument.active;

										var	jsonObject =
													Object.assign(JSON.parse(currentDocument.json.toString()),
															updated);
										removed.forEach(key => delete jsonObject[key]);

										// Add document infos
										returnDocumentInfos.push(
												{
													documentID: documentID,
													revision: revision,
													active: active,
													modificationDate: modificationDate,
													json: jsonObject,
												});
										documentUpdateTracker.addDocumentInfo(
												{
													id: id,
													revision: revision,
													active: active,
													json: jsonObject,
													updatedProperties: Object.keys(updated).concat(removed),
												});

										// Queue
										statementPerformer.queueUpdate(tablesInfo.infoTable,
												[
													{tableColumn: tablesInfo.infoTable.revisionTableColumn,
															value: revision},
													{tableColumn: tablesInfo.infoTable.activeTableColumn,
															value: active},
												],
												statementPerformer.where(tablesInfo.infoTable.idTableColumn, id));
										statementPerformer.queueUpdate(tablesInfo.contentTable,
												[
													{tableColumn: tablesInfo.contentTable.modificationDateTableColumn,
															value: modificationDate},
													{tableColumn: tablesInfo.contentTable.jsonTableColumn,
															value: JSON.stringify(jsonObject)},
												],
												statementPerformer.where(tablesInfo.contentTable.idTableColumn, id));
										
										// Update
										lastRevision += 1;
									}
									this.queueUpdateLastRevision(statementPerformer, documentType, lastRevision);
									documentUpdateTracker.finalize(statementPerformer, initialLastRevision);

									return [returnDocumentInfos, null];
								})()});

			return results;
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'Unknown documentType: ' + documentType];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentAdd(statementPerformer, documentType, documentID, info, content) {
		// Validate
		if (!info)
			return [null, 'Missing info'];
		if (!content)
			return [null, 'Missing content'];

		// Setup
		let	internals = this.internals;

		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(statementPerformer, tablesInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Create table if needed
		await internals.createTableIfNeeded(statementPerformer, tablesInfo.attachmentTable);

		// Perform with tables locked
		let	tables = [this.documentsTable, tablesInfo.infoTable, tablesInfo.attachmentTable];
		
		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
					// Setup
					let	initialLastRevision = await this.getLastRevision(statementPerformer, documentType);

					// Add attachment
					let	revision = initialLastRevision + 1;
					let attachmentID = this.newID();

					statementPerformer.queueInsertInto(tablesInfo.attachmentTable,
							[
								{tableColumn: tablesInfo.attachmentTable.idTableColumn, value: id},
								{tableColumn: tablesInfo.attachmentTable.attachmentIDTableColumn, value: attachmentID},
								{tableColumn: tablesInfo.attachmentTable.revisionTableColumn, value: 1},
								{tableColumn: tablesInfo.attachmentTable.infoTableColumn, value: JSON.stringify(info)},
								{tableColumn: tablesInfo.attachmentTable.contentTableColumn, value: content},
							]);
					statementPerformer.queueUpdate(tablesInfo.infoTable,
							[{tableColumn: tablesInfo.infoTable.revisionTableColumn, value: revision}],
							statementPerformer.where(tablesInfo.infoTable.idTableColumn, id));
					this.queueUpdateLastRevision(statementPerformer, documentType, revision);
					
					return [{id: attachmentID, revision: 1}, null];
				})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentGet(statementPerformer, documentType, documentID, attachmentID) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		let	[id, error] = await this.getIDForDocumentID(statementPerformer, tablesInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.attachmentTable,
								[tablesInfo.attachmentTable.contentTableColumn],
								statementPerformer.where(tablesInfo.attachmentTable.attachmentIDTableColumn,
										attachmentID));
			if (results.length > 0)
				// Success
				return [results[0].content.toString(), null];
			else
				// Error
				return [null, 'Unknown attachmentID: ' + attachmentID];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'Unknown documentType: ' + documentType];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentUpdate(statementPerformer, documentType, documentID, attachmentID, info, content) {
		// Validate
		if (!info)
			return [null, 'Missing info'];
		if (!content)
			return [null, 'Missing content'];

		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(statementPerformer, tablesInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Perform with tables locked
		let	tables = [this.documentsTable, tablesInfo.infoTable, tablesInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
						// Catch errors
						try {
							// Setup
							let	documentRevision = await this.getLastRevision(statementPerformer, documentType);

							// Retrieve attachment info
							let	results =
										await statementPerformer.select(true, tablesInfo.attachmentTable,
												[tablesInfo.attachmentTable.revisionTableColumn],
												statementPerformer.where(
														tablesInfo.attachmentTable.attachmentIDTableColumn,
														attachmentID));
							var	attachmentRevision;
							if (results.length > 0)
								// Success
								attachmentRevision = results[0].revision + 1;
							else
								// Error
								return [null, 'Unknown attachmentID: ' + attachmentID];

							// Update
							statementPerformer.queueUpdate(tablesInfo.attachmentTable,
									[
										{tableColumn: tablesInfo.attachmentTable.revisionTableColumn,
												value: attachmentRevision},
										{tableColumn: tablesInfo.attachmentTable.infoTableColumn,
												value: JSON.stringify(info)},
										{tableColumn: tablesInfo.attachmentTable.contentTableColumn, value: content},
									],
									statementPerformer.where(tablesInfo.attachmentTable.attachmentIDTableColumn,
											attachmentID));
							statementPerformer.queueUpdate(tablesInfo.infoTable,
									[{tableColumn: tablesInfo.infoTable.revisionTableColumn, value: documentRevision}],
									statementPerformer.where(tablesInfo.infoTable.idTableColumn, id));
							this.queueUpdateLastRevision(statementPerformer, documentType, documentRevision);

							return [{revision: attachmentRevision}, null];
						} catch (error) {
							// Check error
							if (error.message.startsWith('ER_NO_SUCH_TABLE'))
								// No such table
								return [null, 'Unknown attachmentID: ' + attachmentID];
							else
								// Other error
								throw error;
						}
					})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentRemove(statementPerformer, documentType, documentID, attachmentID) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		let	[id, error] = await this.getIDForDocumentID(statementPerformer, tablesInfo, documentID);
		if (!id)
			// Error
			return error;

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.attachmentTable,
								[tablesInfo.attachmentTable.contentTableColumn],
								statementPerformer.where(tablesInfo.attachmentTable.attachmentIDTableColumn,
										attachmentID));
			if (results.length == 0)
				// Error
				return 'Unknown attachmentID: ' + attachmentID;
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return 'Unknown documentType: ' + documentType;
			else
				// Other error
				throw error;
		}

		// Perform with tables locked
		let	tables = [this.documentsTable, tablesInfo.infoTable, tablesInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
					// Setup
					let	initialLastRevision = await this.getLastRevision(statementPerformer, documentType);

					// Update
					let	revision = initialLastRevision + 1;
					statementPerformer.queueDelete(tablesInfo.attachmentTable,
							statementPerformer.where(tablesInfo.attachmentTable.attachmentIDTableColumn,
									attachmentID));
					statementPerformer.queueUpdate(tablesInfo.infoTable,
							[{tableColumn: tablesInfo.infoTable.revisionTableColumn, value: revision}],
							statementPerformer.where(tablesInfo.infoTable.idTableColumn, id));
					this.queueUpdateLastRevision(statementPerformer, documentType, revision);
					
					return null;
				})()});
	}

	// Internal methods
	//------------------------------------------------------------------------------------------------------------------
	async getIDsForDocumentIDs(statementPerformer, documentType, documentIDs) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Retrieve document ids
			let	results =
						await statementPerformer.select(true, tablesInfo.infoTable,
								[tablesInfo.infoTable.idTableColumn, tablesInfo.infoTable.documentIDTableColumn],
								statementPerformer.where(tablesInfo.infoTable.documentIDTableColumn, documentIDs));
			
			// Compose results
			var	info = {};
			for (let result of results)
				// Update info
				info[result.documentID] = result.id;
			
			// Validate results
			for (let documentID of documentIDs) {
				// Check this documentID
				if (!info[documentID])
					// Not found
					return [null, 'Unknown documentID: ' + documentID];
			}

			return [info, null];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Documents'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	getDocumentIDTableColumnString(statementPerformer, documentType, asName) {
		// Setup
		let	documentIDTableColumn = this.tablesInfo(statementPerformer, documentType).infoTable.documentIDTableColumn;

		return documentIDTableColumn.getNameWithTableAs(asName);
	}

	//------------------------------------------------------------------------------------------------------------------
	getInnerJoinForDocumentInfo(statementPerformer, documentType, idTableColumn) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		return statementPerformer.innerJoin(tablesInfo.infoTable, idTableColumn, tablesInfo.infoTable.idTableColumn);
	}

	//------------------------------------------------------------------------------------------------------------------
	getInnerJoinForDocument(statementPerformer, documentType, idTableColumn) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		return statementPerformer.innerJoin(
				[tablesInfo.infoTable, idTableColumn, tablesInfo.infoTable.idTableColumn],
				[tablesInfo.contentTable, idTableColumn, tablesInfo.contentTable.idTableColumn]);
	}

	//------------------------------------------------------------------------------------------------------------------
	getInnerJoinForDocumentInfos(statementPerformer, documentType1, idTableColumn1, documentType2, idTableColumn2) {
		// Setup
		let	tablesInfo1 = this.tablesInfo(statementPerformer, documentType1);
		let	tablesInfo2 = this.tablesInfo(statementPerformer, documentType2);

		return statementPerformer.innerJoin(
				[tablesInfo1.infoTable, idTableColumn1, tablesInfo1.infoTable.idTableColumn],
				[tablesInfo2.infoTable, idTableColumn2, tablesInfo2.infoTable.idTableColumn]);
	}

	//------------------------------------------------------------------------------------------------------------------
	async getCount(statementPerformer, documentType) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Get count
			let	count = await statementPerformer.count(tablesInfo.infoTable);

			return [count, null];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Documents'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocumentInfos(statementPerformer, documentType, table, innerJoin, where, limit) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Check where
			if (Array.isArray(where)) {
				// Multi-select
				let	results =
							await statementPerformer.multiSelect(true, table, where,
									[
										tablesInfo.infoTable.documentIDTableColumn,
										tablesInfo.infoTable.revisionTableColumn,
									],
									innerJoin);

				return [results, null];
			} else {
				// Select
				let	results =
							await statementPerformer.select(true, table,
									[
										tablesInfo.infoTable.documentIDTableColumn,
										tablesInfo.infoTable.revisionTableColumn,
									],
									innerJoin, where, limit);
									
				return [results, null];
			}
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'No Documents'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async getDocuments(statementPerformer, documentType, table, innerJoin, where, limit) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		var	selectResults = null;
		var	ids = [];
		var	documentsByID = {};
		try {
			// Check where
			if (Array.isArray(where)) {
				// Multi-select
				selectResults =
						await statementPerformer.multiSelect(true, table, where,
								[
									tablesInfo.infoTable.idTableColumn,
									tablesInfo.infoTable.documentIDTableColumn,
									tablesInfo.infoTable.revisionTableColumn,
									tablesInfo.infoTable.activeTableColumn,
									tablesInfo.contentTable.creationDateTableColumn,
									tablesInfo.contentTable.modificationDateTableColumn,
									tablesInfo.contentTable.jsonTableColumn,
								],
								innerJoin);

				// Handle results
				if (selectResults.length == 0)
					// No results
					return [[], [], null];
					
				for (let result of selectResults) {
					// Update info
					ids.push(result.id);
					documentsByID[result.id] =
							{
								documentID: result.documentID,
								revision: result.revision,
								active: result.active,
								creationDate: result.creationDate,
								modificationDate: result.modificationDate,
								json: JSON.parse(result.json.toString()),
								attachments: {},
							};
				}
			} else {
				// Select
				selectResults =
						await statementPerformer.select(true, table,
								[
									tablesInfo.infoTable.idTableColumn,
									tablesInfo.infoTable.documentIDTableColumn,
									tablesInfo.infoTable.revisionTableColumn,
									tablesInfo.infoTable.activeTableColumn,
									tablesInfo.contentTable.creationDateTableColumn,
									tablesInfo.contentTable.modificationDateTableColumn,
									tablesInfo.contentTable.jsonTableColumn,
								],
								innerJoin, where, limit);

				// Handle results
				if (selectResults.length == 0)
					// No results
					return [[], [], null];
					
				for (let result of selectResults) {
					// Update info
					ids.push(result.id);
					documentsByID[result.id] =
							{
								documentID: result.documentID,
								revision: result.revision,
								active: result.active,
								creationDate: result.creationDate,
								modificationDate: result.modificationDate,
								json: JSON.parse(result.json.toString()),
								attachments: {},
							};
				}
			}
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, null, 'No Documents'];
			else
				// Other error
				throw error;
		}

		// Retrieve attachments
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.attachmentTable,
								[
									tablesInfo.attachmentTable.idTableColumn,
									tablesInfo.attachmentTable.attachmentIDTableColumn,
									tablesInfo.attachmentTable.revisionTableColumn,
									tablesInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(tablesInfo.attachmentTable.idTableColumn, ids));
			
			// Handle results
			for (let result of results)
				// Add attachment info
				documentsByID[result.id].attachments[result.attachmentID] =
						{revision: result.revision, info: JSON.parse(result.info.toString())};
		} catch (error) {
			// Check error
			if (!error.message.startsWith('ER_NO_SUCH_TABLE'))
				// Other error
				throw error;
		}

		return [selectResults, documentsByID, null];
	}

	//------------------------------------------------------------------------------------------------------------------
	async getUpdateDocumentInfos(statementPerformer, documentType, sinceRevision, count) {
		// Setup
		let	tablesInfo = this.tablesInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, tablesInfo.infoTable,
								[
									tablesInfo.infoTable.idTableColumn,
									tablesInfo.infoTable.revisionTableColumn,
									tablesInfo.infoTable.activeTableColumn,
									tablesInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(tablesInfo.contentTable,
										tablesInfo.contentTable.idTableColumn),
								statementPerformer.where(tablesInfo.infoTable.revisionTableColumn, '>',
										sinceRevision),
								statementPerformer.orderBy(tablesInfo.infoTable.revisionTableColumn),
								statementPerformer.limit(null, count));

			return results.map(result =>
					{
						return {
							id: result.id,
							revision: result.revision,
							active: result.active,
							json: JSON.parse(result.json.toString()),
						};
					});
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [];
			else
				// Other error
				throw error;
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	newID() {
		// Return new UUID converted to Base64 and replacing characters that cause URL issues
		return Buffer.from(UuidTool.toBytes(UuidTool.newUuid())).toString('base64')
				.slice(0, 22)
				.replace(/\+/g, '_')
				.replace(/\//g, '-');
	}

	//------------------------------------------------------------------------------------------------------------------
	tablesInfo(statementPerformer, documentType) {
		// Setup
		let	TableColumn = statementPerformer.tableColumn();

		// Setup document
		var	tablesInfo = this.tablesInfoInfo[documentType];
		if (!tablesInfo) {
			// Setup
			let	infoTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 's';
			let	contentTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 'Contents';
			let	attachmentTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 'Attachments';

			tablesInfo =
					{
						documentType: documentType,
						infoTable:
								statementPerformer.table(infoTableName,
										[
											new TableColumn.INT('id',
													TableColumn.options.primaryKey | TableColumn.options.nonNull |
															TableColumn.options.unsigned |
															TableColumn.options.autoIncrement,
													infoTableName),
											new TableColumn.VARCHAR('documentID',
													TableColumn.options.nonNull | TableColumn.options.unique, 22,
													infoTableName),
											new TableColumn.INT('revision',
													TableColumn.options.nonNull | TableColumn.options.unsigned),
											new TableColumn.TINYINT('active',
													TableColumn.options.nonNull | TableColumn.options.unsigned),
										]),
						contentTable:
								statementPerformer.table(contentTableName,
										[
											new TableColumn.INT('id',
													TableColumn.options.primaryKey | TableColumn.options.nonNull |
															TableColumn.options.unsigned,
													contentTableName),
											new TableColumn.VARCHAR('creationDate', TableColumn.options.nonNull, 28),
											new TableColumn.VARCHAR('modificationDate', TableColumn.options.nonNull,
													28),
											new TableColumn.LONGBLOB('json', TableColumn.options.nonNull),
										]),
						attachmentTable:
								statementPerformer.table(attachmentTableName,
										[
											new TableColumn.INT('id',
													TableColumn.options.nonNull | TableColumn.options.unsigned,
													attachmentTableName),
											new TableColumn.VARCHAR('attachmentID',
													TableColumn.options.primaryKey | TableColumn.options.nonNull |
															TableColumn.options.unique,
													22),
											new TableColumn.INT('revision',
													TableColumn.options.nonNull | TableColumn.options.unsigned),
											new TableColumn.LONGBLOB('info', TableColumn.options.nonNull),
											new TableColumn.LONGBLOB('content', TableColumn.options.nonNull),
										]),
					};
			this.tablesInfoInfo[documentType] = tablesInfo;
		}

		return tablesInfo;
	}

	//------------------------------------------------------------------------------------------------------------------
	async getLastRevision(statementPerformer, documentType) {
		// Catch errors
		try {
			// Retrieve document type info
			let	results =
						await statementPerformer.select(false, this.documentsTable,
								statementPerformer.where(this.documentsTable.typeTableColumn, documentType));
			
			return (results.length > 0) ? results[0].lastRevision : null;
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return null;
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	queueUpdateLastRevision(statementPerformer, documentType, lastRevision) {
		// Queue
		statementPerformer.queueReplace(this.documentsTable,
			[
				{tableColumn: this.documentsTable.typeTableColumn, value: documentType},
				{tableColumn: this.documentsTable.lastRevisionTableColumn, value: lastRevision},
			]);
	}

	//------------------------------------------------------------------------------------------------------------------
	async getIDForDocumentID(statementPerformer, tablesInfo, documentID) {
		// Catch errors
		try {
			// Retrieve document id
			let	results =
						await statementPerformer.select(false, tablesInfo.infoTable,
								[tablesInfo.infoTable.idTableColumn],
								statementPerformer.where(tablesInfo.infoTable.documentIDTableColumn, documentID));
			if (results.length > 0)
				// documentID found!
				return [results[0].id, null];
			else
				// documentID not found
				return [null, 'Unknown documentID: ' + documentID];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null, 'Unknown documentType: ' + tablesInfo.documentType];
			else
				// Other error
				throw error;
		}
	}
}
