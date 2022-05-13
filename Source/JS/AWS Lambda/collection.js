//
//  collection.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{documentStorage} = require('globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"name" :String,
//			"documentType" :String,
//			"relevantProperties" :[String],
//			"isUpToDate" :Int (0 or 1)
//			"isIncludedSelector" :String,
//			"isIncludedSelectorInfo" :{
//											"key" :Any,
//											...
//									  },
//		}
exports.registerV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	info = (event.body) ? JSON.parse(event.body) : {};

	// Catch errors
	try {
		// Get info
		let	error = await documentStorage.collectionRegister(documentStorageID, info);
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
// MARK: Get Document Count
//	=> documentStorageID (path)
//	=> name (path)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= count in header
exports.getDocumentCountV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	name = event.pathParameters.name.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	[count, upToDate] = await documentStorage.collectionGetDocumentCount(documentStorageID, name);
		if (upToDate)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: count,
			};
		else
			// Not up to date
			return {
					statusCode: 409,
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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
//	=> documentStorageID (path)
//	=> name (path)
//	=> startIndex (query) (optional, default is 0)
//	=> count (query) (optional, default is all)
//	=> fullInfo (query) (optional, default is false)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= json (fullInfo == 0)
//		{
//			String (documentID) : Int (revision),
//			...
//		}
//	<= json (fullInfo == 1)
//		[
//			{
//				"documentID" :String,
//				"revision" :Int,
//				"active" :0/1,
//				"creationDate" :String,
//				"modificationDate" :String,
//				"json" :{
//							"key" :Any,
//							...
//						},
//				"attachments":
//						{
//							id :
//								{
//									"revision" :Int,
//									"info" :{
//												"key" :Any,
//												...
//											},
//								},
//								..
//						}
//			},
//			...
//		]
exports.getDocumentsV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/%2B/g, '+');
	let	name = event.pathParameters.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	queryStringParameters = event.queryStringParameters || {};
	let	startIndex = queryStringParameters.startIndex || 0;

	// Catch errors
	try {
		// Get info
		let	[upToDate, totalCount, results, error] =
					await documentStorage.collectionGetDocuments(documentStorageID, name, startIndex, count,
							fullInfo == 1);
		if (upToDate) {
			// Success
			let	endIndex = startIndex + Object.keys(results).length - 1;
			let	contentRange =
						(totalCount > 0) ?
								'documents ' + startIndex + '-' + endIndex + '/' + totalCount : 'documents */0';

			return {
					statusCode: 200,
					headers:
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Access-Control-Expose-Headers': 'Content-Range',
								'Content-Range': contentRange,
							},
					body: JSON.stringify(results),
			};
		} else if (!error)
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
