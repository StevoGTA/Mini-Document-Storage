//
//  Documents.js
//
//  Created by Stevo on 3/1/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	util = require('util');
let	uuid = require('uuid');
let	uuidBase64 = require('uuid-base64');

//----------------------------------------------------------------------------------------------------------------------
// Documents
module.exports = class Documents {

	// Properties
	documentInfoInfo = {};

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
			return [null, 'Missing infos'];

		// Setup
		let	internals = this.internals;

		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Create tables if needed
		await internals.createTableIfNeeded(statementPerformer, this.documentsTable);
		await internals.createTableIfNeeded(statementPerformer, documentInfo.infoTable);
		await internals.createTableIfNeeded(statementPerformer, documentInfo.contentTable);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(statementPerformer, documentType);

		// Perform with tables locked
		let	tables =
					[this.documentsTable, documentInfo.infoTable, documentInfo.contentTable]
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

									let	documentID = info.documentID || uuidBase64.encode(uuid.v4());
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
									statementPerformer.queueInsertInto(documentInfo.infoTable,
											[
												{tableColumn: documentInfo.infoTable.documentIDTableColumn,
														value: documentID},
												{tableColumn: documentInfo.infoTable.revisionTableColumn,
														value: revision},
												{tableColumn: documentInfo.infoTable.activeTableColumn, value: 1},
											]);
									statementPerformer.queueSet(idVariableName, 'LAST_INSERT_ID()');
									statementPerformer.queueInsertInto(documentInfo.contentTable,
									[
										{tableColumn: documentInfo.contentTable.idTableColumn,
												variable: idVariableName},
										{tableColumn: documentInfo.contentTable.creationDateTableColumn,
												value: creationDate},
										{tableColumn: documentInfo.contentTable.modificationDateTableColumn,
												value: modificationDate},
										{tableColumn: documentInfo.contentTable.jsonTableColumn,
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
		if (!sinceRevision)
			return [null, null, 'Missing sinceRevision'];

		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);
		let	where = statementPerformer.where(documentInfo.infoTable.revisionTableColumn, '>', sinceRevision);

		// Count relevant documents
		var	totalCount;
		try {
			// Perform
			totalCount = await statementPerformer.count(documentInfo.infoTable, where);

			// Quick check for no documents
			if (totalCount == 0)
				// Nothing to do
				return [0, [], null];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [0, [], null];
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
						await statementPerformer.select(true, documentInfo.infoTable,
								[
									documentInfo.infoTable.idTableColumn,
									documentInfo.infoTable.documentIDTableColumn,
									documentInfo.infoTable.revisionTableColumn,
									documentInfo.infoTable.activeTableColumn,
									documentInfo.contentTable.creationDateTableColumn,
									documentInfo.contentTable.modificationDateTableColumn,
									documentInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(documentInfo.contentTable,
										documentInfo.contentTable.idTableColumn),
								where,
								statementPerformer.orderBy(documentInfo.infoTable.revisionTableColumn),
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
						await statementPerformer.select(true, documentInfo.attachmentTable,
								[
									documentInfo.attachmentTable.idTableColumn,
									documentInfo.attachmentTable.attachmentIDTableColumn,
									documentInfo.attachmentTable.revisionTableColumn,
									documentInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(documentInfo.attachmentTable.idTableColumn, ids));
			
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
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		var	ids = [];
		var	documentsByID = {};
		try {
			// Retrieve relevant documents
			let	results =
						await statementPerformer.select(true, documentInfo.infoTable,
								[
									documentInfo.infoTable.idTableColumn,
									documentInfo.infoTable.documentIDTableColumn,
									documentInfo.infoTable.revisionTableColumn,
									documentInfo.infoTable.activeTableColumn,
									documentInfo.contentTable.creationDateTableColumn,
									documentInfo.contentTable.modificationDateTableColumn,
									documentInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(documentInfo.contentTable,
										documentInfo.contentTable.idTableColumn),
								statementPerformer.where(documentInfo.infoTable.documentIDTableColumn, documentIDs));
			if (results.length != documentIDs.length)
				// Not all documents were found
				return [null, 'Not all documentIDs were found'];

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
				return [null, 'No Documents'];
			else
				// Other error
				throw error;
		}

		// Retrieve attachments
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, documentInfo.attachmentTable,
								[
									documentInfo.attachmentTable.idTableColumn,
									documentInfo.attachmentTable.attachmentIDTableColumn,
									documentInfo.attachmentTable.revisionTableColumn,
									documentInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(documentInfo.attachmentTable.idTableColumn, ids));
			
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

		// Setup
		let	internals = this.internals;

		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(statementPerformer, documentType);

		// Catch errors
		try {
			// Perform with tables locked
			let	tables =
						[this.documentsTable, documentInfo.infoTable, documentInfo.contentTable]
								.concat(documentUpdateTracker.tables());
			let	results =
						await statementPerformer.batchLockedForWrite(tables,
								() => { return (async() => {
									// Setup
									let	initialLastRevision =
												await this.getLastRevision(statementPerformer, documentType);

									// Retrieve current document info
									let	results =
												await statementPerformer.select(true, documentInfo.infoTable,
														[
															documentInfo.infoTable.idTableColumn,
															documentInfo.infoTable.documentIDTableColumn,
															documentInfo.infoTable.activeTableColumn,
															documentInfo.contentTable.jsonTableColumn,
														],
														statementPerformer.innerJoin(documentInfo.contentTable,
																documentInfo.infoTable.idTableColumn),
														statementPerformer.where(
																documentInfo.infoTable.documentIDTableColumn,
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
											return [null, 'Document for ' + documentID + ' not found.'];
										
										let	id = currentDocument.id;
										let	revision = lastRevision + 1;
										let	active = info.active;
										let	modificationDate = new Date().toISOString();

										var	jsonObject =
													Object.assign(JSON.parse(currentDocument.json.toString()),
															info.updated);
										info.removed.forEach(key => delete jsonObject[key]);

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
													updatedProperties: Object.keys(info.updated).concat(info.removed),
												});

										// Queue
										statementPerformer.queueUpdate(documentInfo.infoTable,
												[
													{tableColumn: documentInfo.infoTable.revisionTableColumn,
															value: revision},
													{tableColumn: documentInfo.infoTable.activeTableColumn,
															value: active},
												],
												statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
										statementPerformer.queueUpdate(documentInfo.contentTable,
												[
													{tableColumn: documentInfo.contentTable.modificationDateTableColumn,
															value: modificationDate},
													{tableColumn: documentInfo.contentTable.jsonTableColumn,
															value: JSON.stringify(jsonObject)},
												],
												statementPerformer.where(documentInfo.contentTable.idTableColumn, id));
										
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
				return [null, 'No Documents'];
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

		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(statementPerformer, documentInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Create table if needed
		await internals.createTableIfNeeded(statementPerformer, documentInfo.attachmentTable);

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];
		
		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
					// Setup
					let	initialLastRevision = await this.getLastRevision(statementPerformer, documentType);

					// Add attachment
					let	revision = initialLastRevision + 1;
					let	attachmentID = uuidBase64.encode(uuid.v4());

					statementPerformer.queueInsertInto(documentInfo.attachmentTable,
							[
								{tableColumn: documentInfo.attachmentTable.idTableColumn, value: id},
								{tableColumn: documentInfo.attachmentTable.attachmentIDTableColumn,
										value: attachmentID},
								{tableColumn: documentInfo.attachmentTable.revisionTableColumn, value: 1},
								{tableColumn: documentInfo.attachmentTable.infoTableColumn,
										value: JSON.stringify(info)},
								{tableColumn: documentInfo.attachmentTable.contentTableColumn,
										value: content},
							]);
					statementPerformer.queueUpdate(documentInfo.infoTable,
							[{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision}],
							statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
					this.queueUpdateLastRevision(statementPerformer, documentType, revision);
					
					return [{id: attachmentID}, null];
				})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentGet(statementPerformer, documentType, documentID, attachmentID) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, documentInfo.attachmentTable,
								[documentInfo.attachmentTable.contentTableColumn],
								statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn,
										attachmentID));
			if (results.length > 0)
				// Success
				return [results[0].content.toString(), null];
			else
				// Error
				return [null,
						'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' + documentType +
								' not found.'];
		} catch (error) {
			// Check error
			if (error.message.startsWith('ER_NO_SUCH_TABLE'))
				// No such table
				return [null,
						'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' + documentType +
								' not found.'];
			else
				// Other error
				throw error;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentUpdate(statementPerformer, documentType, documentID, attachmentID, info, content) {
		// Validate
		if (!info)
			return 'Missing info';
		if (!content)
			return 'Missing content';

		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(statementPerformer, documentInfo, documentID);
		if (!id)
			// Error
			return error;

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
						// Catch errors
						try {
							// Setup
							let	documentRevision = await this.getLastRevision(statementPerformer, documentType);

							// Retrieve attachment info
							let	results =
										await statementPerformer.select(true, documentInfo.attachmentTable,
												[documentInfo.attachmentTable.revisionTableColumn],
												statementPerformer.where(
														documentInfo.attachmentTable.attachmentIDTableColumn,
														attachmentID));
							var	attachmentRevision;
							if (results.length > 0)
								// Success
								attachmentRevision = results[0].revision + 1;
							else
								// Error
								return 'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' + documentType +
										' not found.';

							// Update
							statementPerformer.queueUpdate(documentInfo.attachmentTable,
									[
										{tableColumn: documentInfo.attachmentTable.revisionTableColumn,
												value: attachmentRevision},
										{tableColumn: documentInfo.attachmentTable.infoTableColumn, value: info},
										{tableColumn: documentInfo.attachmentTable.contentTableColumn, value: content},
									],
									statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn,
											attachmentID));
							statementPerformer.queueUpdate(documentInfo.infoTable,
									[{tableColumn: documentInfo.infoTable.revisionTableColumn,
											value: documentRevision}],
									statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
							this.queueUpdateLastRevision(statementPerformer, documentType, documentRevision);

							return null;
						} catch (error) {
							// Check error
							if (error.message.startsWith('ER_NO_SUCH_TABLE'))
								// No such table
								return 'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' +
										documentType + ' not found.';
							else
								// Other error
								throw error;
						}
					})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentRemove(statementPerformer, documentType, documentID, attachmentID) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		let	[id, error] = await this.getIDForDocumentID(statementPerformer, documentInfo, documentID);
		if (!id)
			// Error
			return error;

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables,
				() => { return (async() => {
					// Catch errors
					try {
						// Setup
						let	initialLastRevision = await this.getLastRevision(statementPerformer, documentType);

						// Update
						let	revision = initialLastRevision + 1;
						statementPerformer.queueDelete(documentInfo.attachmentTable,
								statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn,
										attachmentID));
						statementPerformer.queueUpdate(documentInfo.infoTable,
								[{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision}],
								statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
						this.queueUpdateLastRevision(statementPerformer, documentType, revision);
						
						return null;
					} catch (error) {
						// Check error
						if (error.message.startsWith('ER_NO_SUCH_TABLE'))
							// No such table
							return 'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' + documentType +
									' not found.';
						else
							// Other error
							throw error;
					}
				})()});
	}

	// Internal methods
	//------------------------------------------------------------------------------------------------------------------
	async getIDsForDocumentIDs(statementPerformer, documentType, documentIDs) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Retrieve document ids
			let	results =
						await statementPerformer.select(true, documentInfo.infoTable,
								[documentInfo.infoTable.idTableColumn, documentInfo.infoTable.documentIDTableColumn],
								statementPerformer.where(documentInfo.infoTable.documentIDTableColumn, documentIDs));
			if (results.length == documentIDs.length) {
				// documentIDs found!
				var	info = {};
				for (let result of results)
					// Update info
					info[result.documentID] = result.id;

				return [info, null];
			} else
				// Not all documentIDs not found
				return [null, 'Not all documentIDs found'];
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
	getDocumentInfoInnerJoin(statementPerformer, documentType, idTableColumn) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		return statementPerformer.innerJoin(documentInfo.infoTable, idTableColumn,
				documentInfo.infoTable.idTableColumn);
	}

	//------------------------------------------------------------------------------------------------------------------
	getDocumentInnerJoin(statementPerformer, documentType, idTableColumn) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		return statementPerformer.innerJoin(
				[documentInfo.infoTable, idTableColumn, documentInfo.infoTable.idTableColumn],
				[documentInfo.contentTable, idTableColumn, documentInfo.contentTable.idTableColumn]);
	}

	//------------------------------------------------------------------------------------------------------------------
	async getCount(statementPerformer, documentType) {
		// Setup
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Get count
			let	count = await statementPerformer.count(documentInfo.infoTable);

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
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Check where
			if (Array.isArray(where)) {
				// Multi-select
				let	results =
							await statementPerformer.multiSelect(true, table, where,
									[
										documentInfo.infoTable.documentIDTableColumn,
										documentInfo.infoTable.revisionTableColumn,
									],
									innerJoin);

				return [results, null];
			} else {
				// Select
				let	results =
							await statementPerformer.select(true, table,
									[
										documentInfo.infoTable.documentIDTableColumn,
										documentInfo.infoTable.revisionTableColumn,
									],
									innerJoin, where, limit);
				
				var	infos = {};
				for (let result of results)
					// Update infos
					infos[result.documentID] = result.revision;
				
				return [infos, null];
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
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

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
									documentInfo.infoTable.idTableColumn,
									documentInfo.infoTable.documentIDTableColumn,
									documentInfo.infoTable.revisionTableColumn,
									documentInfo.infoTable.activeTableColumn,
									documentInfo.contentTable.creationDateTableColumn,
									documentInfo.contentTable.modificationDateTableColumn,
									documentInfo.contentTable.jsonTableColumn,
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
									documentInfo.infoTable.idTableColumn,
									documentInfo.infoTable.documentIDTableColumn,
									documentInfo.infoTable.revisionTableColumn,
									documentInfo.infoTable.activeTableColumn,
									documentInfo.contentTable.creationDateTableColumn,
									documentInfo.contentTable.modificationDateTableColumn,
									documentInfo.contentTable.jsonTableColumn,
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
						await statementPerformer.select(true, documentInfo.attachmentTable,
								[
									documentInfo.attachmentTable.idTableColumn,
									documentInfo.attachmentTable.attachmentIDTableColumn,
									documentInfo.attachmentTable.revisionTableColumn,
									documentInfo.attachmentTable.infoTableColumn,
								],
								statementPerformer.where(documentInfo.attachmentTable.idTableColumn, ids));
			
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
		let	documentInfo = this.documentInfo(statementPerformer, documentType);

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(true, documentInfo.infoTable,
								[
									documentInfo.infoTable.idTableColumn,
									documentInfo.infoTable.revisionTableColumn,
									documentInfo.infoTable.activeTableColumn,
									documentInfo.contentTable.jsonTableColumn,
								],
								statementPerformer.innerJoin(documentInfo.contentTable,
										documentInfo.contentTable.idTableColumn),
								statementPerformer.where(documentInfo.infoTable.revisionTableColumn, '>',
										sinceRevision),
								statementPerformer.orderBy(documentInfo.infoTable.revisionTableColumn),
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
	documentInfo(statementPerformer, documentType) {
		// Setup
		let	TableColumn = statementPerformer.tableColumn();

		// Setup document
		var	documentInfo = this.documentInfoInfo[documentType];
		if (!documentInfo) {
			// Setup
			let	infoTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 's';
			let	contentTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 'Contents';
			let	attachmentTableName = documentType.charAt(0).toUpperCase() + documentType.slice(1) + 'Attachments';

			documentInfo =
					{
						infoTable:
								statementPerformer.table(infoTableName,
										[
											new TableColumn.INT('id',
													TableColumn.options.primaryKey | TableColumn.options.nonNull |
															TableColumn.options.unsigned |
															TableColumn.options.autoIncrement,
													infoTableName),
											new TableColumn.VARCHAR('documentID',
													TableColumn.options.nonNull | TableColumn.options.unique, 22),
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
			this.documentInfo[documentType] = documentInfo;
		}

		return documentInfo;
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
	async getIDForDocumentID(statementPerformer, documentInfo, documentID) {
		// Catch errors
		try {
			// Retrieve document id
			let	results =
						await statementPerformer.select(false, documentInfo.infoTable,
								[documentInfo.infoTable.idTableColumn],
								statementPerformer.where(documentInfo.infoTable.documentIDTableColumn, documentID));
			if (results.length > 0)
				// documentID found!
				return [results[0].id, null];
			else
				// documentID not found
				return [null, 'Document for ' + documentID + ' not found'];
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
}
