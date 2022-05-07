//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Create
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> json (body)
//		[
//			{
//				"documentID" :String (optional)
//				"creationDate" :String (optional)
//				"modificationDate" :String (optional)
//				"json" :{
//							"key" :Any,
//							...
//						}
//			},
//			...
//		]
//
//	<= json
//		[
//			{
//				"documentID" :String,
//				"revision" :Int,
//				"creationDate" :String,
//				"modificationDate" :String,
//			},
//			...
//		]
exports.createV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Count
//	=> documentStorageID (path)
//	=> type (path)
//
//	<= count in header
exports.getCountV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;

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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
//	=> documentStorageID (path)
//	=> type (path)
//
//	=> sinceRevision (query)
//	=> count (query, optional)
//		-or-
//	=> id (query) (can specify multiple)
//
//	<= json
//		[
//			{
//				"documentID" :String,
//				"revision" :Int,
//				"active" :0/1,
//				"creationDate" :String,
//				"modificationDate" :String,
//				"json" :{
//							"key" :Any,
//							...
//						},
//				"attachments":
//						{
//							id :
//								{
//									"revision" :Int,
//									"info" :{
//												"key" :Any,
//												...
//											},
//								},
//								..
//						}
//			},
//			...
//		]
exports.getV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;

	let	sinceRevision = request.query.sinceRevision;
	let	count = request.query.count;
	
	var	documentIDs = request.query.id || [];
	if (typeof documentIDs == 'string')
		documentIDs = [documentIDs];
	// Convert back to + and from _ to /
	documentIDs = documentIDs.map(documentID => documentID.replace(/%2B/g, '+'));

	// Catch errors
	try {
		// Check request type
		if (sinceRevision) {
			// Since revision
			let	[totalCount, results, error] =
						await request.app.locals.documentStorage.documentGetSinceRevision(documentStorageID,
								documentType, sinceRevision, count);
			if (!error)
				// Success
				response
						.status(200)
						.set({
							'Access-Control-Allow-Origin': '*',
							'Access-Control-Allow-Credentials': true,
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
								documentType, documentIDs);
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update
//	=> documentStorageID (path)
//	=> type (path)
//	=> json (body)
//		[
//			{
//				"documentID" :String
//				"updated" :{
//								"key" :Any,
//								...
//						   }
//				"removed" :[
//								"key",
//								...
//						   ]
//				"active" :0/1
//			},
//			...
//		]
//
//	<= json
//		[
//			{
//				"documentID" :String,
//				"revision" :Int,
//				"active" :0/1,
//				"modificationDate" :String,
//				"json" :{
//							"key" :Any,
//							...
//						},
//			},
//			...
//		]
exports.updateV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
	let	infos = request.body;

	// Catch errors
	try {
		// Get info
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Add Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> info (body)
//	=> content (body)
exports.addAttachmentV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+');
	let info = request.body.info;
	let	content = request.body.content;

	// Catch errors
	try {
		// Get info
		let	[results, error] =
					await request.app.locals.documentStorage.documentAttachmentAdd(documentStorageID, documentType,
							documentID, info, Buffer.from(content, 'base64'));
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
//
//	<= data
exports.getAttachmentV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+');

	// Catch errors
	try {
		// Get info
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
//	=> info (body)
//	=> content (body)
exports.updateAttachmentV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+');
	let info = request.body.info;
	let	content = request.body.content;

	// Catch errors
	try {
		// Get info
		let	error =
					await request.app.locals.documentStorage.documentAttachmentUpdate(documentStorageID, documentType,
							documentID, attachmentID, info, Buffer.from(content, 'base64'));
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Remove Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
exports.removeAttachmentV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+');

	// Catch errors
	try {
		// Get info
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};
