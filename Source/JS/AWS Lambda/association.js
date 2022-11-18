//
//  association.js
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
	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Register association
		let	error = await documentStorage.associationRegister(documentStorageID, info);
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
// MARK: Update
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	name = decodeURIComponent(event.pathParameters.name);
	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Update association
		let	error = await documentStorage.associationUpdate(documentStorageID, name, infos);
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
// MARK: Get Document Infos
exports.getDocumentsV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	name = decodeURIComponent(event.pathParameters.name);

	let	queryStringParameters = event.queryStringParameters || {};
	let	fromDocumentID = queryStringParameters.fromID ? decodeURIComponent(queryStringParameters.fromID) : null;
	let	toDocumentID = queryStringParameters.toID ? decodeURIComponent(queryStringParameters.toID) : null;
	let	startIndex = queryStringParameters.startIndex || 0;
	let	count = queryStringParameters.count;
	let	fullInfo = queryStringParameters.fullInfo || 0;

	// Catch errors
	try {
		// Get document infos
		let	[totalCount, results, error] =
					await documentStorage.associationGetDocumentInfos(documentStorageID, name, fromDocumentID,
							toDocumentID, startIndex, count, fullInfo == 1);
		if (!error) {
			// Success
			let	endIndex = startIndex + Object.keys(results).length - 1;
			let	contentRange =
						(totalCount > 0) ?
								'documents ' + startIndex + '-' + endIndex + '/' + totalCount : 'documents */0';

			return {
					statusCode: 200,
					headers: {
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Credentials': true,
						'Access-Control-Expose-Headers': 'Content-Range',
						'Content-Range': contentRange,
					},
					body: JSON.stringify(results),
				};
		} else
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
// MARK: Get Association Value
exports.getValueV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);
	let	name = decodeURIComponent(event.pathParameters.name);
	let	action = event.pathParameters.action;

	let	queryStringParameters = event.queryStringParameters || {};
	let	fromDocumentID = decodeURIComponent(queryStringParameters.fromID);
	let	cacheName = decodeURIComponent(queryStringParameters.cacheName);
	let	cachedValueName = decodeURIComponent(queryStringParameters.cachedValueName);

	// Catch errors
	try {
		// Get Association value
		let	[upToDate, value, error] =
					await documentStorage.associationGetValue(documentStorageID, name, action, fromDocumentID,
							cacheName, cachedValueName);
		if (upToDate)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: value,
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
