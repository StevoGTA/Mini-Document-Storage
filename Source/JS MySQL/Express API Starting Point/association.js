//
//  association.js
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
//			"name" :String
//			"fromDocumentType" :String,
//			"toDocumentType" :String,
//		}
exports.registerV1 = async (request, response, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID;

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
		await MDSDocumentStorage.associationRegister(documentStorageID, info);

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
exports.updateV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID;
	let	name = request.params.name;

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
		await MDSDocumentStorage.associationUpdate(documentStorageID, name, info);

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
//	=> fromID -or- toID (query)
//	=> startIndex (query) (optional, default 0)
//	=> fullInfo (query) (optional, default false)
//
//	<= json
//		{
//			String (documentID) : Int (revision),
//			...
//		}
exports.getDocumentInfosV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID;
	let	name = request.params.name;

	let	fromDocumentID = request.query.fromID;
	let	toDocumentID = request.query.toID;
	let	startIndex = request.query.startIndex || 0;
	let	fullInfo = request.query.fullInfo || 0;

	// Validate input
	if ((!fromDocumentID && !toDocumentID) || (fromDocumentID && toDocumentID))
		// Must specify fromDocumentID or toDocumentID
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'must specify fromDocumentID or toDocumentID'});

	// Catch errors
	try {
		// Get info
		let	[totalCount, results] =
					await MDSDocumentStorage.associationGetDocumentInfos(documentStorageID, name, fromDocumentID,
							toDocumentID, startIndex, fullInfo == 1);

		// Success
		let	endIndex = startIndex + Object.keys(results).length - 1;
		let	contentRange =
					(totalCount > 0) ?
							'documents ' + startIndex + '-' + endIndex + '/' + totalCount : 'documents */0';

		response
				.statusCode(200)
				.set({
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Allow-Credentials': true,
					'Content-Range': contentRange,
				})
				.send(results);
	} catch (error) {
		// Error
		response
				.statusCode(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Error: ' + error);
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
exports.getValueV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID;
	let	name = request.params.name;

	let	toDocumentID = request.query.toID;
	let	action = request.query.action;
	let	cacheName = request.query.cacheName;
	let	cacheValueName = request.query.cacheValueName;

	// Validate input
	if (!toDocumentID || !action || !cacheName || !cacheValueName)
		// Must specify fromDocumentID or toDocumentID
		response
				.statusCode(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'must specify toID, action, cacheName, and cacheValueName'});

	// Catch errors
	try {
		// Get info
		let	[value, upToDate] =
					await MDSDocumentStorage.associationGetValue(documentStorageID, name, toDocumentID, action,
							cacheName, cacheValueName);
		if (upToDate)
			// Success
			response
					.statusCode(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(value);
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
