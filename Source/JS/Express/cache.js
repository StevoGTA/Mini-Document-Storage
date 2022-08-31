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
	let	documentStorageID = request.params.documentStorageID.replace(/_/g, '/');	// Convert back to /
	let	info = request.body || {};

	// Catch errors
	try {
		// Get info
		let	error = await request.app.locals.documentStorage.cacheRegister(documentStorageID, info);
		if (!error)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		else
			// Error
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.error(error.stack);

		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};
