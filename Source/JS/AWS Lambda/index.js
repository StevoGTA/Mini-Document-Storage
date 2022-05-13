//
//  index.js
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
exports.registerV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Get info
		let	error = await documentStorage.indexRegister(documentStorageID, info);
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
exports.getDocumentsV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	name = event.pathParameters.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	multiValueQueryStringParameters = event.multiValueQueryStringParameters || {};
	let	keys = multiValueQueryStringParameters.key;

	// Catch errors
	try {
		// Get info
		let	[upToDate, results, error] =
					await documentStorage.indexGetDocuments(documentStorageID, name, keys, fullInfo == 1);
		if (upToDate)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: JSON.stringify(results),
			};
		else if (!error)
			// Not up to date
			return {
					statusCode: 409,
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
