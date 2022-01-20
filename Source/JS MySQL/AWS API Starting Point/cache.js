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
exports.registerV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.projectID;

	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!info)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info'}),
		};

	// Prevent timeout from waiting on event loop
	context.callbackWaitsForEmptyEventLoop = false;

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		await mdsDocumentStorage.cacheRegister(documentStorageID, info);

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
