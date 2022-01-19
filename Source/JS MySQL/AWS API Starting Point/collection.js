//
//  collection.js
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
//			"relevantProperties" :[String],
//			"isUpToDate" :Int (0 or 1)
//			"isIncludedSelector" :String,
//			"isIncludedSelectorInfo" :{
//											"key" :Any,
//											...
//									  },
//		}
exports.registerV1 = async (event, context) => {
	// Setup
	let	pathParameters = event.pathParameters || {};
	let	documentStorageID = pathParameters.projectID;

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
		await MDSDocumentStorage.collectionRegister(documentStorageID, info);

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
// MARK: Get Document Count
//	=> documentStorageID (path)
//	=> name (path)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= count in header
exports.getDocumentCountV1 = async (event, context) => {
	// Setup
	let	pathParameters = event.pathParameters || {};
	let	documentStorageID = pathParameters.projectID;
	let	name = pathParameters.name.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		let	[count, upToDate] =
					await MDSDocumentStorage.collectionGetDocumentCount(documentStorageID, name);
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
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= json
//		{
//			String (documentID) : Int (revision),
//			...
//		}
exports.getDocumentInfosV1 = async (event, context) => {
	// Setup
	let	pathParameters = event.pathParameters || {};
	let	documentStorageID = pathParameters.projectID;
	let	name = pathParameters.name.replace(/%2B/g, '+').replace(/_/g, '/');
	let	startIndex = queryStringParameters.startIndex || 0;

	// Catch errors
	try {
		// Get info
		let	[totalCount, results, upToDate] =
					await MDSDocumentStorage.collectionGetDocumentInfos(documentStorageID, name, startIndex);
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
								'Content-Range': contentRange,
							},
					body: JSON.stringify(results)
			};
		} else
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