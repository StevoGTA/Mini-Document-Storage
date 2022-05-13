//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{documentStorage} = require('./globals');

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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Create documents
		let	[results, error] = await documentStorage.documentCreate(documentStorageID, documentType, infos);
		if (!error)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify(results),
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		// Error
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: error})
		};
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Count
//	=> documentStorageID (path)
//	=> type (path)
//
//	<= count in header
exports.getCountV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;

	// Catch errors
	try {
		// Get document count
		let	[count, error] = await documentStorage.documentGetCount(documentStorageID, documentType);
		if (!error)
			// Success
			return {
					statusCode: 200,
					headers:
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Access-Control-Expose-Headers': 'Content-Range',
								'Content-Range': 'documents */' + count,
							},
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		// Error
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: error})
		};
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
exports.getV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;

	let	queryStringParameters = event.queryStringParameters || {};
	let	sinceRevision = queryStringParameters.sinceRevision;
	let	count = queryStringParameters.count;

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	var	documentIDs = (multiValueQueryStringParameters.id || []).map(documentID => documentID.replace(/%2B/g, '+'));	// Convert back to +);

	// Catch errors
	try {
		// Check request type
		if (sinceRevision) {
			// Since revision
			let	[totalCount, results, error] =
						await documentStorage.documentGetSinceRevision(documentStorageID, documentType, sinceRevision,
								count);
			if (!error)
				// Success
				return {
						statusCode: 200,
						headers:
								{
									'Access-Control-Allow-Origin': '*',
									'Access-Control-Allow-Credentials': true,
									'Access-Control-Expose-Headers': 'Content-Range',
									'Content-Range':
											(totalCount > 0) ?
													'documents 0-' + (results.length - 1) + '/' + totalCount :
													'documents */0',
						},
						body: JSON.stringify(results),
				};
			else
				// Error
				return {
						statusCode: 400,
						headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
						body: JSON.stringify({error: error})
				};
		} else {
			// DocumentIDs
			let	[results, error] =
						await documentStorage.documentGetForDocumentIDs(documentStorageID, documentType, documentIDs);
			if (results)
				// Success
				return {
						statusCode: 200,
						headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
						body: JSON.stringify(results),
				};
			else
				// Error
				return {
						statusCode: 400,
						headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
						body: JSON.stringify({error: error})
				};
		}
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
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
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Get info
		let	[results, error] = await documentStorage.documentUpdate(documentStorageID, documentType, infos);
		if (results)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify(results),
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;

	// Catch errors
	try {
		// Get info
		let	[results, error] =
					await documentStorage.documentAttachmentAdd(documentStorageID, documentType, documentID, info,
							Buffer.from(content, 'base64'));
		if (results)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify(results),
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
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
//	<= data
exports.getAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+');

	// Catch errors
	try {
		// Get info
		let	[results, error] =
					await request.app.locals.documentStorage.documentAttachmentGet(documentStorageID, documentType,
							documentID, attachmentID);
		if (results)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: results,
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+');

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;

	// Catch errors
	try {
		// Get info
		let	error =
					await documentStorage.documentAttachmentUpdate(documentStorageID, documentType, documentID,
							attachmentID, info, Buffer.from(content, 'base64'));
		if (!error)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	documentType = event.pathParameters.documentType;
	let	documentID = event.pathParameters.documentID.replace(/%2B/g, '+');
	let	attachmentID = event.pathParameters.attachmentID.replace(/%2B/g, '+');

	// Catch errors
	try {
		// Get info
		let	error =
					await request.app.locals.documentStorage.documentAttachmentRemove(documentStorageID, documentType,
							documentID, attachmentID);
		if (!error)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
			};
		else
			// Error
			return {
					statusCode: 400,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify({error: error})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
		};
	}
};
