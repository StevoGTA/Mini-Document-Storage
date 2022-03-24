//
//  association.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

let	{DocumentStorage} = require('mini-document-storage');

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
	let	documentStorageID = event.pathParameters.documentStorageID;

	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!info)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.associationRegister(documentStorageID, info);

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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Update
//	=> documentStorageID (path)
//	=> name (path)
//	=> json (body)
//		[
//			{
//				"action" :"add", "update", or "remove"
//				"fromID" :String
//				"toID :String
//			}
//		]
exports.updateV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID;
	let	name = event.pathParameters.name;

	let	info = (event.body) ? JSON.parse(event.body) : null;

	// Validate input
	if (!info)
		// Must specify keys
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'missing info'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		await documentStorage.associationUpdate(documentStorageID, name, info);

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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
//	=> documentStorageID (path)
//	=> name (path)
//	=> fromID -or- toID (query)
//	=> startIndex (query) (optional, default 0)
//	=> fullInfo (query) (optional, default false)
//
//	<= json
//		{
//			String (documentID) : Int (revision),
//			...
//		}
exports.getDocumentInfosV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID;
	let	name = event.pathParameters.name;

	let	queryStringParameters = event.queryStringParameters || {};
	let	fromDocumentID = queryStringParameters.fromID;
	let	toDocumentID = queryStringParameters.toID;
	let	startIndex = queryStringParameters.startIndex || 0;
	let	fullInfo = queryStringParameters.fullInfo || 0;

	// Validate input
	if ((!fromDocumentID && !toDocumentID) || (fromDocumentID && toDocumentID))
		// Must specify fromDocumentID or toDocumentID
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'must specify fromDocumentID or toDocumentID'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	[totalCount, results] =
					await documentStorage.associationGetDocumentInfos(documentStorageID, name, fromDocumentID,
							toDocumentID, startIndex, fullInfo == 1);

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
							'Content-Range': contentRange,
						},
				body: JSON.stringify(results),
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
// MARK: Get Association Value
//	=> documentStorageID (path)
//	=> name (path)
//	=> toID (query)
//	=> action (query)
//	=> cacheName (query)
//	=> cacheValueName (query)
//
//	<= count
exports.getValueV1 = async (event) => {
	// Setup
	let	documentStorageID = event.pathParameters.documentStorageID;
	let	name = event.pathParameters.name;

	let	queryStringParameters = event.queryStringParameters || {};
	let	toDocumentID = queryStringParameters.toID;
	let	action = queryStringParameters.action;
	let	cacheName = queryStringParameters.cacheName;
	let	cacheValueName = queryStringParameters.cacheValueName;

	// Validate input
	if (!toDocumentID || !action || !cacheName || !cacheValueName)
		// Must specify fromDocumentID or toDocumentID
		return {
				statusCode: 400,
				headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
				body: JSON.stringify({message: 'must specify toID, action, cacheName, and cacheValueName'}),
		};

	// Catch errors
	try {
		// Get info
		let	documentStorage = new DocumentStorage();
		let	[value, upToDate] =
					await documentStorage.associationGetValue(documentStorageID, name, toDocumentID, action,
							cacheName, cacheValueName);
		if (upToDate)
			// Success
			return {
					statusCode: 200,
					headers: {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true},
					body: value,
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
