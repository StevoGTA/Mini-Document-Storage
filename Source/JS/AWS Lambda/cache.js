//
//  cache.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{documentStorage} = require('./globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"name" :String,
//			"documentType" :String,
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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	info = (event.body) ? JSON.parse(event.body) : {};

	// Catch errors
	try {
		// Get info
		let	error = await documentStorage.cacheRegister(documentStorageID, info);
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
