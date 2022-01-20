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
exports.getV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	keys = request.query.key;

	// Validate input
	if (!keys)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing key(s)'})

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		let	results = await mdsDocumentStorage.infoGet(documentStorageID, keys);

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
// MARK: Set
//	=> documentStorageID (path)
//	=> json (body)
//		[
//			"key" :String
//			...
//		]
exports.setV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	info = request.body;

	// Validate input
	if (!info)
		// Must specify info
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info'});

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		await mdsDocumentStorage.infoSet(documentStorageID, info);

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
