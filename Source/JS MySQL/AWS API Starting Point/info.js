//
//  info.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{MDSDocumentStorage} = require('mini-document-storage-mysql');

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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

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
		let	mdsDocumentStorage = new MDSDocumentStorage();
		let	results = await mdsDocumentStorage.infoGet(documentStorageID, keys);

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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

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
		let	mdsDocumentStorage = new MDSDocumentStorage();
		await mdsDocumentStorage.infoSet(documentStorageID, info);

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
