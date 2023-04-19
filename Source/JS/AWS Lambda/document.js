//
//  document.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	{documentStorage} = require('./globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Create
exports.createV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	infos = event.body ? JSON.parse(event.body) : null;

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
					body: JSON.stringify({error: error.toString()})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		// Error
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: error.toString()})
		};
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Count
exports.getCountV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);

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
					body: JSON.stringify({error: error.toString()})
			};
	} catch (error) {
		// Error
		console.error(error.stack);

		// Error
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: error.toString()})
		};
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
exports.getV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);

	let	queryStringParameters = event.queryStringParameters || {};
	let	sinceRevision = parseInt(queryStringParameters.sinceRevision);
	let	count = queryStringParameters.count;
	let	fullInfo = queryStringParameters.fullInfo == 1;

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	let	documentIDs = (multiValueQueryStringParameters.id || []) .map(documentID => decodeURIComponent(documentID));

	// Catch errors
	try {
		// Check request type
		if (!isNaN(sinceRevision)) {
			// Since revision
			let	[totalCount, results, error] =
						await documentStorage.documentGetSinceRevision(documentStorageID, documentType, sinceRevision,
								count, fullInfo);
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
						body: JSON.stringify({error: error.toString()})
				};
		} else {
			// DocumentIDs
			let	[results, error] =
						await documentStorage.documentGetForDocumentIDs(documentStorageID, documentType, documentIDs,
								fullInfo);
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
						body: JSON.stringify({error: error.toString()})
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	infos = event.body ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Update Document
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
					body: JSON.stringify({error: error.toString()})
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Add Attachment
exports.addAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	documentID = decodeURIComponent(event.pathParameters.documentID);

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;

	// Catch errors
	try {
		// Add Document Attachment
		let	[results, error] =
					await documentStorage.documentAttachmentAdd(documentStorageID, documentType, documentID, info,
							(content != null) ? Buffer.from(content, 'base64') : null);
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
					body: JSON.stringify({error: error.toString()})
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Attachment
exports.getAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	documentID = decodeURIComponent(event.pathParameters.documentID);
	let	attachmentID = decodeURIComponent(event.pathParameters.attachmentID);

	// Catch errors
	try {
		// Get Document Attachment
		let	[results, error] =
					await documentStorage.documentAttachmentGet(documentStorageID, documentType, documentID,
							attachmentID);
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
					body: JSON.stringify({error: error.toString()})
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update Attachment
exports.updateAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID)
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	documentID = decodeURIComponent(event.pathParameters.documentID);
	let	attachmentID = decodeURIComponent(event.pathParameters.attachmentID);

	let	body = JSON.parse(event.body || {});
	let info = body.info;
	let	content = body.content;

	// Catch errors
	try {
		// Update Document Attachment
		let	[results, error] =
					await documentStorage.documentAttachmentUpdate(documentStorageID, documentType, documentID,
							attachmentID, info, (content != null) ? Buffer.from(content, 'base64') : null);
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
					body: JSON.stringify({error: error.toString()})
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Remove Attachment
exports.removeAttachmentV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	documentType = decodeURIComponent(event.pathParameters.documentType);
	let	documentID = decodeURIComponent(event.pathParameters.documentID);
	let	attachmentID = decodeURIComponent(event.pathParameters.attachmentID);

	// Catch errors
	try {
		// Remove Document Attachment
		let	error =
					await documentStorage.documentAttachmentRemove(documentStorageID, documentType, documentID,
							attachmentID);
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
					body: JSON.stringify({error: error.toString()})
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
}
