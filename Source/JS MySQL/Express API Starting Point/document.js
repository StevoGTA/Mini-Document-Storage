//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{MDSDocumentStorage} = require('mini-document-storage-mysql');

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
exports.createV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;

	let	infos = request.body;

	// Validate input
	if (!infos)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info(s)'});

	// Catch errors
	try {
		// Get info
		let	results = await MDSDocumentStorage.documentCreate(documentStorageID, documentType, infos);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send(results);
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
//	=> documentStorageID (path)
//	=> type (path)
//	=> sinceRevision (query)
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
//			},
//			...
//		]
exports.getV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;

	let	sinceRevision = request.query.sinceRevision;
	var	ids = request.query.id || [];
	for (var i = 0; i < ids.length; i++)
		ids[i] = ids[i].replace(/%2B/g, '+').replace(/_/g, '/');	// Convert back to + and from _ to /

	let	infos = request.body;

	// Validate input
	if ((ids.length == 0) && !sinceRevision)
		// Must specify documentIDs or sinceRevision
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'must specify id(s) or sinceRevision'});

	// Catch errors
	try {
		// Check request type
		if (sinceRevision) {
			// Since revision
			let	[totalCount, results] =
						await MDSDocumentStorage.documentGetSinceRevision(documentStorageID, documentType,
								sinceRevision);

			response
					.statusCode(200)
					.set({
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Credentials': true,
						'Content-Range':
								(totalCount > 0) ?
										'documents 0-' + (results.length - 1) + '/' + totalCount : 'documents */0',
					})
					.send(results);
		} else {
			// IDs
			let	results = await MDSDocumentStorage.documentGetIDs(documentStorageID, documentType, ids);

			response
					.statusCode(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		}
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
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
//				"updated" :[
//								"key" :Any,
//								...
//						   ]
//				"removed" :[
//								"key",
//								...
//						   ]
//				"active" :0/1
//			},
//			...
//		]
exports.updateV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;

	let	infos = request.body;

	// Validate input
	if (!infos)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info(s)'});

	// Catch errors
	try {
		// Get info
		await MDSDocumentStorage.documentUpdate(documentStorageID, documentType, infos);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true});
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
//
//	<= string
exports.getAttachmentV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	// Validate input
	if (!infos)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info(s)'});

	// Catch errors
	try {
		// Get info
		let	results =
					await MDSDocumentStorage.documentAttachmentGet(documentStorageID, documentType, documentID,
							attachmentID);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send(results);
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Add Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> info (body)
//	=> content (body)
exports.addAttachmentV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;
	
	// Validate input
	if (!info || !content)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info and/or content'});

	// Catch errors
	try {
		// Get info
		await MDSDocumentStorage.documentAttachmentAdd(documentStorageID, documentType, documentID, info, content);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true});
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
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
exports.updateAttachmentV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;
	
	// Validate input
	if (!info || !content)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info and/or content'});

	// Catch errors
	try {
		// Get info
		await MDSDocumentStorage.documentAttachmentUpdate(documentStorageID, documentType, documentID, attachmentID,
				info, content);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true});
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Remove Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
exports.removeAttachmentV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = request.params.documentType;
	let	documentID = request.params.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = request.params.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		await MDSDocumentStorage.documentAttachmentRemove(documentStorageID, documentType, documentID, attachmentID);

		response
				.statusCode(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true});
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};
