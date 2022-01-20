//
//  index.js
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
//			"isUpToDate" :Int (0 or 1)
//			"keysSelector" :String,
//			"keysSelectorInfo" :{
//									"key" :Any,
//									...
//							    },
//		}
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

	// Catch errors
	try {
		// Get info
		await MDSDocumentStorage.indexRegister(documentStorageID, info);

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
exports.getDocumentInfosV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.projectID;
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	keys = request.query.key;

	// Validate input
	if (!keys)
		// Must specify projectID
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing key(s)'});

	// Catch errors
	try {
		// Get info
		let	[results, upToDate] = await MDSDocumentStorage.indexGetDocumentInfos(documentStorageID, name, keys);
		if (upToDate)
			// Success
			response
					.statusCode(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
		else
			// Not up to date
			response
					.statusCode(409)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true});
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
	}
};
