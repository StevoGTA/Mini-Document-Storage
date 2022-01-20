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
		let	mdsDocumentStorage = new MDSDocumentStorage();
		await mdsDocumentStorage.collectionRegister(documentStorageID, info);

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
// MARK: Get Document Count
//	=> documentStorageID (path)
//	=> name (path)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= count in header
exports.getDocumentCountV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.projectID;
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		let	[count, upToDate] =
					await mdsDocumentStorage.collectionGetDocumentCount(documentStorageID, name);
		if (upToDate)
			// Success
			response
					.statusCode(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(count);
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
exports.getDocumentInfosV1 = async (request, result, next) => {
	// Setup
	let	documentStorageID = request.params.projectID;
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	startIndex = request.query.startIndex || 0;

	// Catch errors
	try {
		// Get info
		let	mdsDocumentStorage = new MDSDocumentStorage();
		let	[totalCount, results, upToDate] =
					await mdsDocumentStorage.collectionGetDocumentInfos(documentStorageID, name, startIndex);
		if (upToDate) {
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
		} else
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
