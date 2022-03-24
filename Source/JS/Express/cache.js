//
//  cache.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

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
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	info = request.body || {};

	// Catch errors
	try {
		// Get info
		let	result = await request.app.locals.documentStorage.cacheRegister(documentStorageID, info);
		if (!result)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		else
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({message: result});
	} catch (error) {
		// Error
		console.log(error.stack);

		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Uh Oh');
	}
};
