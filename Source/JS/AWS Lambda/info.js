//
//  info.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{DocumentStorage} = require('mini-document-storage');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
//	=> documentStorageID (path)
//	=> key (query) (can specify multiple)
//
//	<= [
//		"key" :String
//		...
//	   ]
exports.getV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	let	keys = multiValueQueryStringParameters.key;

	// Validate input
	if (!keys)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing key(s)'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	results = await documentStorage.infoGet(documentStorageID, keys);

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
// MARK: Set
//	=> documentStorageID (path)
//	=> json (body)
//		[
//			"key" :String
//			...
//		]
exports.setV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');

	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!info)
		// Must specify info
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.infoSet(documentStorageID, info);

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
