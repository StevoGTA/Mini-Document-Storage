//
//  index.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"documentType" :String,
//			"name" :String,
//			"relevantProperties" :[String]
//			"isUpToDate" :Int (0 or 1)
//			"keysSelector" :String,
//			"keysSelectorInfo" :{
//									"key" :Any,
//									...
//							    },
//		}
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	info = request.body;

	// Catch errors
	try {
		// Get info
		let	result = await request.app.locals.documentStorage.indexRegister(documentStorageID, info);
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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
//	=> documentStorageID (path)
//	=> name (path)
//	=> key (query) (can specify multiple)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= json
//		{
//			String (key) :
//				{
//					String (documentID) : Int (revision)
//				}
//			...
//		}
exports.getDocumentInfosV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	keys = request.query.key;

	// Validate input
	if (!keys) {
		// Must specify projectID
		response
				.status(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing key(s)'});

		return;
	}

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	[results, upToDate] = await documentStorage.indexGetDocumentInfos(documentStorageID, name, keys);
		if (upToDate)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Not up to date
			response
					.status(409)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
	} catch (error) {
		// Error
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Uh Oh');
	}
};
