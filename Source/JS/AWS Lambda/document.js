//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{DocumentStorage} = require('mini-document-storage');

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
exports.createV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;

	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!infos)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info(s)'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	results = await documentStorage.documentCreate(documentStorageID, documentType, infos);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify(results),
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
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
exports.getV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;

	let	queryStringParameters = event.queryStringParameters || {};
	let	sinceRevision = queryStringParameters.sinceRevision;

	let	infos = (event.body) ? JSON.parse(event.body) : null;

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	var	ids = multiValueQueryStringParameters.id || [];
	for (var i = 0; i < ids.length; i++)
		ids[i] = ids[i].replace(/%2B/g, '+').replace(/_/g, '/');	// Convert back to + and from _ to /

	// Validate input
	if ((ids.length == 0) && !sinceRevision)
		// Must specify documentIDs or sinceRevision
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'must specify id(s) or sinceRevision'}),
		};

	// Catch errors
	try {
		// Check request type
		if (sinceRevision) {
			// Since revision
			let	documentStorage = new DocumentStorage();
			let	[totalCount, results] =
						await documentStorage.documentGetSinceRevision(documentStorageID, documentType,
								sinceRevision);

			return {
					statusCode: 200,
					headers:
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Content-Range':
										(totalCount > 0) ?
												'documents 0-' + (results.length - 1) + '/' + totalCount :
												'documents */0',
							},
					body: JSON.stringify(results),
			};
		} else {
			// IDs
			let	documentStorage = new DocumentStorage();
			let	results = await documentStorage.documentGetForIDs(documentStorageID, documentType, ids);

			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify(results),
			};
		}
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
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
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;

	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!infos)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info(s)'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.documentUpdate(documentStorageID, documentType, infos);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
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
exports.getAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	// Validate input
	if (!infos)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info(s)'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	results =
					await documentStorage.documentAttachmentGet(documentStorageID, documentType, documentID,
							attachmentID);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: results,
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Add Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> info (body)
//	=> content (body)
exports.addAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;
	
	// Validate input
	if (!info || !content)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info and/or content'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.documentAttachmentAdd(documentStorageID, documentType, documentID, info, content);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
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
exports.updateAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;
	
	// Validate input
	if (!info || !content)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info and/or content'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.documentAttachmentUpdate(documentStorageID, documentType, documentID, attachmentID,
				info, content);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Remove Attachment
//	=> documentStorageID (path)
//	=> documentType (path)
//	=> documentID (path)
//	=> attachmentID (path)
exports.removeAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.documentAttachmentRemove(documentStorageID, documentType, documentID, attachmentID);

		return {
				statusCode: 200,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
		};
	} catch (error) {
		// Error
		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: 'Error: ' + error,
		};
	}
};
