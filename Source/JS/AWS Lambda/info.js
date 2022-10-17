//
//  info.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	{documentStorage} = require('./globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
exports.getV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters.documentStorageID);

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	let	keys = multiValueQueryStringParameters.key.map(key => decodeURIComponent(key));

	// Catch errors
	try {
		// Get info
		let	[results, error] = await documentStorage.infoGet(documentStorageID, keys);
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

		return {
				statusCode: 500,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: '{"error": "Internal error"}',
		};
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Set
exports.setV1 = async (event) => {
	// Setup
	let	documentStorageID = decodeURIComponent(event.pathParameters);
	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Set info
		let	error = await documentStorage.infoSet(documentStorageID, info);
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
