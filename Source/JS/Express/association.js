//
//  association.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
//	=> documentStorageID (path)
//	=> json (body)
//		{
//			"name" :String
//			"fromDocumentType" :String,
//			"toDocumentType" :String,
//		}
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	info = request.body;

	// Catch errors
	try {
		// Get info
		let	error = await request.app.locals.documentStorage.associationRegister(documentStorageID, info);
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
exports.updateV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	name = request.params.name;
	let	infos = request.body;

	// Catch errors
	try {
		// Get info
		let	error = await request.app.locals.documentStorage.associationUpdate(documentStorageID, name, infos);
		if (!error)
			// Success
			response
					.status(200)
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

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
//	=> documentStorageID (path)
//	=> name (path)
//	=> fromID -or- toID (query)
//	=> startIndex (query) (optional, default 0)
//	=> count (query) (optional, default is all)
//	=> fullInfo (query) (optional, default false)
//
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
exports.getDocumentsV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	name = request.params.name;
	let	fromDocumentID = request.query.fromID;
	let	toDocumentID = request.query.toID;
	let	startIndex = request.query.startIndex || 0;
	let	count = request.query.count;
	let	fullInfo = request.query.fullInfo || false;

	// Catch errors
	try {
		// Get info
		let	[totalCount, results, error] =
					await request.app.locals.documentStorage.associationGetDocumentInfos(documentStorageID, name,
							fromDocumentID, toDocumentID, startIndex, count, fullInfo == 1);
		if (!error) {
			// Success
			let	endIndex = startIndex + Object.keys(results).length - 1;
			let	contentRange =
						(totalCount > 0) ?
								'documents ' + startIndex + '-' + endIndex + '/' + totalCount : 'documents */0';

			response
					.status(200)
					.set({
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Credentials': true,
						'Content-Range': contentRange,
					})
					.send(results);
		} else
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
exports.getValueV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+');
	let	name = request.params.name;

	let	fromDocumentID = request.query.fromID;
	let	action = request.query.action;
	let	cacheName = request.query.cacheName;
	let	cacheValueName = request.query.cacheValueName;

	// Catch errors
	try {
		// Get info
		let	[upToDate, value, error] =
					await request.app.locals.documentStorage.associationGetValue(documentStorageID, name,
							fromDocumentID, action, cacheName, cacheValueName);
		if (upToDate)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send("" + value);
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
