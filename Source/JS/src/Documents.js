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
	constructor(internals) {
		// Store
		this.internals = internals;

		// Setup
		let	statementPerformer = internals.statementPerformer;
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
	async create(documentType, infos) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Create tables if needed
		await internals.createTableIfNeeded(this.documentsTable);
		await internals.createTableIfNeeded(documentInfo.infoTable);
		await internals.createTableIfNeeded(documentInfo.contentTable);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(documentType);

		// Perform with tables locked
		let	tables =
					[this.documentsTable, documentInfo.infoTable, documentInfo.contentTable]
							.concat(documentUpdateTracker.tables());
		
		return await statementPerformer.batchLockedForWrite(tables, statementPerformer => { return (async() => {
			// Setup
			let	initialLastRevision = await this.getLastRevision(documentType);
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
							{tableColumn: documentInfo.infoTable.documentIDTableColumn, value: documentID},
							{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision},
							{tableColumn: documentInfo.infoTable.activeTableColumn, value: 1},
						]);
				statementPerformer.queueSet(idVariableName, 'LAST_INSERT_ID()');
				statementPerformer.queueInsertInto(documentInfo.contentTable,
				[
					{tableColumn: documentInfo.contentTable.idTableColumn, variable: idVariableName},
					{tableColumn: documentInfo.contentTable.creationDateTableColumn, value: creationDate},
					{tableColumn: documentInfo.contentTable.modificationDateTableColumn, value: modificationDate},
					{tableColumn: documentInfo.contentTable.jsonTableColumn, value: json},
				]);
				
				// Update
				lastRevision += 1;
			}
			this.queueUpdateLastRevision(documentType, lastRevision);
			documentUpdateTracker.finalize();

			return returnDocumentInfos;
		})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async getSinceRevision(documentType, sinceRevision, maxDocumentCount) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

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
						await statementPerformer.select(documentInfo.infoTable,
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
								maxDocumentCount ? statementPerformer.limit(maxDocumentCount) : null);

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
						await statementPerformer.select(documentInfo.attachmentTable,
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
	async getForDocumentIDs(documentType, documentIDs) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Catch errors
		var	ids = [];
		var	documentsByID = {};
		try {
			// Retrieve relevant documents
			let	results =
						await statementPerformer.select(documentInfo.infoTable,
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
				return [[], 'No Documents'];
			else
				// Other error
				throw error;
		}

		// Retrieve attachments
		try {
			// Perform
			let	results =
						await statementPerformer.select(documentInfo.attachmentTable,
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
	async update(documentType, infos) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Get DocumentUpdateTracker
		let	documentUpdateTracker = await internals.getDocumentUpdateTracker(documentType);

		// Catch errors
		try {
			// Perform with tables locked
			let	tables =
						[this.documentsTable, documentInfo.infoTable, documentInfo.contentTable]
								.concat(documentUpdateTracker.tables());

			return await statementPerformer.batchLockedForWrite(tables, statementPerformer => { return (async() => {
				// Setup
				let	initialLastRevision = await this.getLastRevision(documentType);

				// Retrieve current document info
				let	results =
							await statementPerformer.select(documentInfo.infoTable,
									[
										documentInfo.infoTable.idTableColumn,
										documentInfo.infoTable.documentIDTableColumn,
										documentInfo.infoTable.activeTableColumn,
										documentInfo.contentTable.jsonTableColumn,
									],
									statementPerformer.innerJoin(documentInfo.contentTable,
											documentInfo.infoTable.idTableColumn),
									statementPerformer.where(documentInfo.infoTable.documentIDTableColumn,
											Object.values(infos).map(info => info.documentID)));
				let	documentsByID = Object.fromEntries(results.map(result => [result.documentID, result]));

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

					var	jsonObject = Object.assign(JSON.parse(currentDocument.json.toString()), info.updated);
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
								{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision},
								{tableColumn: documentInfo.infoTable.activeTableColumn, value: active},
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
				this.queueUpdateLastRevision(documentType, lastRevision);
				documentUpdateTracker.finalize();

				return [returnDocumentInfos, null];
			})()});
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
	async attachmentAdd(documentType, documentID, info, content) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(documentInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Create table if needed
		await internals.createTableIfNeeded(documentInfo.attachmentTable);

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables, statementPerformer => { return (async() => {
			// Setup
			let	initialLastRevision = await this.getLastRevision(documentType);

			// Add attachment
			let	revision = initialLastRevision + 1;
			let	attachmentID = uuidBase64.encode(uuid.v4());

			statementPerformer.queueInsertInto(documentInfo.attachmentTable,
					[
						{tableColumn: documentInfo.attachmentTable.idTableColumn, value: id},
						{tableColumn: documentInfo.attachmentTable.attachmentIDTableColumn,
								value: attachmentID},
						{tableColumn: documentInfo.attachmentTable.revisionTableColumn, value: 1},
						{tableColumn: documentInfo.attachmentTable.infoTableColumn, value: info},
						{tableColumn: documentInfo.attachmentTable.contentTableColumn, value: content},
					]);
			statementPerformer.queueUpdate(documentInfo.infoTable,
					[{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision}],
					statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
			this.queueUpdateLastRevision(documentType, revision);
			
			return [{id: attachmentID}, null];
		})()});
	}

	//------------------------------------------------------------------------------------------------------------------
	async attachmentGet(documentType, documentID, attachmentID) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Catch errors
		try {
			// Perform
			let	results =
						await statementPerformer.select(documentInfo.attachmentTable,
								[documentInfo.attachmentTable.contentTableColumn],
								statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn,
										attachmentID));
			if (results.length > 0)
				// Success
				return [results[0].content, null];
			else
				// Error
				return [null,
						'Attachment ' + attachmentID + ' for ' + documentID + ' of type ' + documentType + ' not found.'];
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
	async attachmentUpdate(documentType, documentID, attachmentID, info, content) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		// Get ID for documentID
		let	[id, error] = await this.getIDForDocumentID(documentInfo, documentID);
		if (!id)
			// Error
			return [null, error];

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables, statementPerformer => { return (async() => {
			// Catch errors
			try {
				// Setup
				let	documentRevision = await this.getLastRevision(documentType);

				// Retrieve attachment info
				let	results =
							await statementPerformer.select(documentInfo.attachmentTable,
									[documentInfo.attachmentTable.revisionTableColumn],
									statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn,
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
						statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn, attachmentID));
				statementPerformer.queueUpdate(documentInfo.infoTable,
						[{tableColumn: documentInfo.infoTable.revisionTableColumn, value: documentRevision}],
						statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
				this.queueUpdateLastRevision(documentType, documentRevision);

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

	//------------------------------------------------------------------------------------------------------------------
	async attachmentRemove(documentType, documentID, attachmentID) {
		// Setup
		let	internals = this.internals;
		let	statementPerformer = internals.statementPerformer;

		let	documentInfo = this.documentInfo(documentType);

		let	id = await this.getIDForDocumentID(documentInfo, documentID);

		// Perform with tables locked
		let	tables = [this.documentsTable, documentInfo.infoTable, documentInfo.attachmentTable];

		return await statementPerformer.batchLockedForWrite(tables, statementPerformer => { return (async() => {
			// Catch errors
			try {
				// Setup
				let	initialLastRevision = await this.getLastRevision(documentType);

				// Update
				let	revision = initialLastRevision + 1;
				statementPerformer.queueDelete(documentInfo.attachmentTable,
						statementPerformer.where(documentInfo.attachmentTable.attachmentIDTableColumn, attachmentID));
				statementPerformer.queueUpdate(documentInfo.infoTable,
						[{tableColumn: documentInfo.infoTable.revisionTableColumn, value: revision}],
						statementPerformer.where(documentInfo.infoTable.idTableColumn, id));
				this.queueUpdateLastRevision(documentType, revision);
				
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

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	documentInfo(documentType) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;
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
	async getLastRevision(documentType) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Retrieve document type info
		let	results =
					await statementPerformer.select(this.documentsTable,
							statementPerformer.where(this.documentsTable.typeTableColumn, documentType));
		
		return (results.length > 0) ? results[0].lastRevision : 0;
	}

	//------------------------------------------------------------------------------------------------------------------
	queueUpdateLastRevision(documentType, lastRevision) {
		// Queue
		this.internals.statementPerformer.queueReplace(this.documentsTable,
			[
				{tableColumn: this.documentsTable.typeTableColumn, value: documentType},
				{tableColumn: this.documentsTable.lastRevisionTableColumn, value: lastRevision},
			]);
	}

	//------------------------------------------------------------------------------------------------------------------
	async getIDForDocumentID(documentInfo, documentID) {
		// Setup
		let	statementPerformer = this.internals.statementPerformer;

		// Catch errors
		try {
			// Retrieve document id
			let	results =
						await statementPerformer.select(documentInfo.infoTable, [documentInfo.infoTable.idTableColumn],
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
