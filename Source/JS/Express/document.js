//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Create
export async function createV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	infos = request.body;

	// Catch errors
	try {
		// Create documents
		let	[results, error] =
					await request.app.locals.documentStorage.documentCreate(documentStorageID, documentType, infos);
		if (!error)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Count
export async function getCountV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);

	// Catch errors
	try {
		// Get document count
		let	[count, error] =
					await request.app.locals.documentStorage.documentGetCount(documentStorageID, documentType);
		if (!error)
			// Success
			response
					.status(200)
					.set(
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Access-Control-Expose-Headers': 'Content-Range',
								'Content-Range': 'documents */' + count,
							})
					.send();
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
export async function getV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);

	let	sinceRevision = parseInt(request.query.sinceRevision);
	let	count = request.query.count;
	let	fullInfo = request.query.fullInfo == 1;
	
	var	documentIDs = request.query.id || [];
	if (typeof documentIDs == 'string')
		documentIDs = [documentIDs];
	documentIDs = documentIDs.map(documentID => decodeURIComponent(documentID));

	// Catch errors
	try {
		// Check request type
		if (!isNaN(sinceRevision)) {
			// Since revision
			let	[totalCount, results, error] =
						await request.app.locals.documentStorage.documentGetSinceRevision(documentStorageID,
								documentType, sinceRevision, count, fullInfo);
			if (!error)
				// Success
				response
						.status(200)
						.set({
							'Access-Control-Allow-Origin': '*',
							'Access-Control-Allow-Credentials': true,
							'Access-Control-Expose-Headers': 'Content-Range',
							'Content-Range':
									(totalCount > 0) ?
											'documents 0-' + (results.length - 1) + '/' + totalCount : 'documents */0',
						})
						.send(results);
			else
				// Error
				response
						.status(400)
						.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
						.send({error: error});
		} else {
			// DocumentIDs
			let	[results, error] =
						await request.app.locals.documentStorage.documentGetForDocumentIDs(documentStorageID,
								documentType, documentIDs, fullInfo);
			if (results)
				// Success
				response
						.status(200)
						.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
						.send(results);
			else
				// Error
				response
						.status(400)
						.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
						.send({error: error});
		}
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update
export async function updateV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	infos = request.body;

	// Catch errors
	try {
		// Update Document
		let	[results, error] =
					await request.app.locals.documentStorage.documentUpdate(documentStorageID, documentType, infos);
		if (results)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Add Attachment
export async function addAttachmentV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	documentID = decodeURIComponent(request.params.documentID);
	let info = request.body.info;
	let	content = request.body.content;

	// Catch errors
	try {
		// Add Document Attachment
		let	[results, error] =
					await request.app.locals.documentStorage.documentAttachmentAdd(documentStorageID, documentType,
							documentID, info, (content != null) ? Buffer.from(content, 'base64') : null);
		if (results)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Attachment
export async function getAttachmentV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	documentID = decodeURIComponent(request.params.documentID);
	let	attachmentID = decodeURIComponent(request.params.attachmentID);

	// Catch errors
	try {
		// Get Document Attachment
		let	[results, error] =
					await request.app.locals.documentStorage.documentAttachmentGet(documentStorageID, documentType,
							documentID, attachmentID);
		if (results)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update Attachment
export async function updateAttachmentV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	documentID = decodeURIComponent(request.params.documentID);
	let	attachmentID = decodeURIComponent(request.params.attachmentID);
	let info = request.body.info;
	let	content = request.body.content;

	// Catch errors
	try {
		// Update Document Attachment
		let	[results, error] =
					await request.app.locals.documentStorage.documentAttachmentUpdate(documentStorageID, documentType,
							documentID, attachmentID, info, (content != null) ? Buffer.from(content, 'base64') : null);
		if (results)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Remove Attachment
export async function removeAttachmentV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	documentType = decodeURIComponent(request.params.documentType);
	let	documentID = decodeURIComponent(request.params.documentID);
	let	attachmentID = decodeURIComponent(request.params.attachmentID);

	// Catch errors
	try {
		// Remove Document Attachment
		let	error =
					await request.app.locals.documentStorage.documentAttachmentRemove(documentStorageID, documentType,
							documentID, attachmentID);
		if (!error)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}
