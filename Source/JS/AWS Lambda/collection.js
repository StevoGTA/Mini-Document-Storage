//
//  collection.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	{documentStorage} = require('./globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
exports.registerV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	info = event.body ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Register collection
		let	error = await documentStorage.collectionRegister(documentStorageID, info);
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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Count
exports.getDocumentCountV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	name = decodeURIComponent(event.pathParameters.name);

	// Catch errors
	try {
		// Get Document count
		let	[upToDate, count, error] = await documentStorage.collectionGetDocumentCount(documentStorageID, name);
		if (upToDate)
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
		else if (!error)
			// Not up to date
			return {
					statusCode: 409,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
			};
		else
			// Error
			return {
					statusCode: 400,
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
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
exports.getDocumentsV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	name = decodeURIComponent(event.pathParameters.name);

	let	queryStringParameters = event.queryStringParameters || {};
	let	startIndex =
				(queryStringParameters.startIndex != null) ? Number(queryStringParameters.startIndex) : 0;
	let	count = (queryStringParameters.count != null) ? Number(queryStringParameters.count) : null;
	let	fullInfo = queryStringParameters.fullInfo || 0;

	// Validate
	if (!Number.isInteger(startIndex) || (startIndex < 0))
		// Invalid startIndex
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: 'Invalid startIndex: ' + queryStringParameters.startIndex}),
		};
	if ((count != null) && (!Number.isInteger(count) || (count < 1)))
		// Invalid count
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({error: 'Invalid count: ' + queryStringParameters.count}),
		};

	// Catch errors
	try {
		// Get Documents
		let	[upToDate, totalCount, results, error] =
					await documentStorage.collectionGetDocuments(documentStorageID, name, startIndex, count,
							fullInfo == 1);
		if (upToDate) {
			// Success
			let	range = (results.length > 0) ? startIndex + '-' + (startIndex + results.length - 1) : '*';
			let	contentRange = 'documents ' + range + '/' + totalCount;

			return {
					statusCode: 200,
					headers:
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Access-Control-Expose-Headers': 'Content-Range',
								'Content-Range': contentRange,
							},
					body: JSON.stringify(results),
			};
		} else if (!error)
			// Not up to date
			return {
					statusCode: 409,
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
