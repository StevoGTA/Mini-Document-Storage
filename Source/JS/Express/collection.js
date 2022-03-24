//
//  collection.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

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
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	info = request.body;

	// Catch errors
	try {
		// Get info
		let	result = await request.app.locals.documentStorage.collectionRegister(documentStorageID, info);
		if (!result)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		else
			response
					.status(400)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send({message: result});
	} catch (error) {
		// Error
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Uh Oh');
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Count
//	=> documentStorageID (path)
//	=> name (path)
//
//	<= HTTP Status 409 if collection is out of date => call endpoint again
//	<= count in header
exports.getDocumentCountV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	// Catch errors
	try {
		// Get info
		let	[count, upToDate] =
					await request.app.locals.documentStorage.collectionGetDocumentCount(documentStorageID, name);
		if (upToDate)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(count);
		else
			// Not up to date
			response
					.status(409)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
	} catch (error) {
		// Error
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Uh Oh');
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
exports.getDocumentInfosV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');
	let	name = request.params.name.replace(/%2B/g, '+').replace(/_/g, '/');

	let	startIndex = request.query.startIndex || 0;

	// Catch errors
	try {
		// Get info
		let	[totalCount, results, upToDate] =
					await request.app.locals.documentStorage.collectionGetDocumentInfos(documentStorageID, name,
							startIndex);
		if (upToDate) {
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
			// Not up to date
			response
					.status(409)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send();
		} catch (error) {
		// Error
		console.log(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send('Uh Oh');
	}
};
