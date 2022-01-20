//
//  cache.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{MDSDocumentStorage} = require('mini-document-storage-mysql');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"documentType" :String,
//			"name" :String,
//			"version" :Int,
//			"relevantProperties" :[String]
//			"valuesInfos" :[
//							{
//								"name" :String,
//								"valueType" :"integer",
//								"selector" :String,
//							},
//							...
//				 		   ]
exports.registerV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.projectID;

	let	info = request.body;

	// Validate input
	if (!info)
		// Must specify keys
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info'});

	// Prevent timeout from waiting on event loop
	context.callbackWaitsForEmptyEventLoop = false;

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		await mdsDocumentStorage.cacheRegister(documentStorageID, info);

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
