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
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	info = request.body;

	// Catch errors
	try {
		// Get info
		let	error = await request.app.locals.documentStorage.indexRegister(documentStorageID, info);
		if (!error)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		else
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({error: error});
	} catch (error) {
		// Error
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
//	=> documentStorageID (path)
//	=> name (path)
//	=> key (query) (can specify multiple)
//	=> fullInfo (query) (optional, default false)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= json (fullInfo == 0)
//		{
//			key: {String (documentID) : Int (revision)},
//			...
//		}
//	<= json (fullInfo == 1)
//		{
//			key:
//				{
//					"documentID" :String,
//					"revision" :Int,
//					"active" :0/1,
//					"creationDate" :String,
//					"modificationDate" :String,
//					"json" :{
//								"key" :Any,
//								...
//							},
//					"attachments":
//							{
//								id :
//									{
//										"revision" :Int,
//										"info" :{
//													"key" :Any,
//													...
//												},
//									},
//									..
//							}
//				},
//			...
//		}
exports.getDocumentsV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	keys = request.query.key;
	if (typeof keys == 'string')
		keys = [keys];

		let	fullInfo = request.query.fullInfo || false;

	// Catch errors
	try {
		// Get info
		let	[upToDate, results, error] =
					await request.app.locals.documentStorage.indexGetDocuments(documentStorageID, name, keys, fullInfo);
		if (upToDate)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else if (!error)
			// Not up to date
			response
					.status(409)
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
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};
