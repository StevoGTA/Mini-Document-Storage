//
//  association.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	{documentStorage} = require('./globals');

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"name" :String
//			"fromDocumentType" :String,
//			"toDocumentType" :String,
//		}
exports.registerV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/_/g, '/');	// Convert back to /
	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Get info
		let	error = await documentStorage.associationRegister(documentStorageID, info);
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
// MARK: Update
//	=> documentStorageID (path)
//	=> name (path)
//	=> json (body)
//		[
//			{
//				"action" :"add" or "remove"
//				"fromID" :String
//				"toID :String
//			}
//		]
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/_/g, '/');	// Convert back to /
	let	name = event.pathParameters.name;
	let	infos = (event.body) ? JSON.parse(event.body) : null;

	// Catch errors
	try {
		// Get info
		let	error = await documentStorage.associationUpdate(documentStorageID, name, infos);
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
//	=> fromID -or- toID (query)
//	=> startIndex (query) (optional, default 0)
//	=> count (query) (optional, default is all)
//	=> fullInfo (query) (optional, default false)
//
//	<= json (no fromID nor toID given)
//		[
//			{
//				"fromDocumentID" :String,
//				"toDocumentID" :String,
//			},
//			...
//		]
//	<= json (fromID or toID given, fullInfo == 0)
//		[
//			{
//				"documentID" :String,
//				"revision" :Int
//			},
//			...
//		]
//	<= json (fromID or toID given, fullInfo == 1)
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
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/_/g, '/');			// Convert back to /
	let	name = event.pathParameters.name;

	let	queryStringParameters = event.queryStringParameters || {};
	let	fromDocumentID = queryStringParameters.fromID?.replace(/%2B/g, '+').replace(/_/g, '/');	// Convert back to + and /
	let	toDocumentID = queryStringParameters.toID?.replace(/%2B/g, '+').replace(/_/g, '/');		// Convert back to + and /
	let	startIndex = queryStringParameters.startIndex || 0;
	let	count = queryStringParameters.count;
	let	fullInfo = queryStringParameters.fullInfo || 0;

	// Catch errors
	try {
		// Get info
		let	[totalCount, results, error] =
					await documentStorage.associationGetDocumentInfos(documentStorageID, name, fromDocumentID,
							toDocumentID, startIndex, count, fullInfo == 1);
		if (!error) {
			// Success
			let	endIndex = startIndex + Object.keys(results).length - 1;
			let	contentRange =
						(totalCount > 0) ?
								'documents ' + startIndex + '-' + endIndex + '/' + totalCount : 'documents */0';

			return {
					statusCode: 200,
					headers: {
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Credentials': true,
						'Access-Control-Expose-Headers': 'Content-Range',
						'Content-Range': contentRange,
					},
					body: JSON.stringify(results),
				};
		} else
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
// MARK: Get Association Value
//	=> documentStorageID (path)
//	=> name (path)
//	=> fromID (query)
//	=> action (query)
//	=> cacheName (query)
//	=> cacheValueName (query)
//
//	<= count
exports.getValueV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID.replace(/_/g, '/');			// Convert back to /
	let	name = event.pathParameters.name;

	let	queryStringParameters = event.queryStringParameters || {};
	let	fromDocumentID = queryStringParameters.fromID.replace(/%2B/g, '+').replace(/_/g, '/');	// Convert back to + and /
	let	action = queryStringParameters.action;
	let	cacheName = queryStringParameters.cacheName;
	let	cacheValueName = queryStringParameters.cacheValueName;

	// Catch errors
	try {
		// Get info
		let	[upToDate, value, error] =
					await documentStorage.associationGetValue(documentStorageID, name, fromDocumentID, action,
							cacheName, cacheValueName);
		if (upToDate)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: value,
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
