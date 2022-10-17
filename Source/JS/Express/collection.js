//
//  collection.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	info = request.body || {};

	// Catch errors
	try {
		// Get info
		let	error = await request.app.locals.documentStorage.collectionRegister(documentStorageID, info);
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Count
exports.getDocumentCountV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);

	// Catch errors
	try {
		// Get info
		let	[upToDate, count, error] =
					await request.app.locals.documentStorage.collectionGetDocumentCount(documentStorageID, name);
		if (upToDate)
			// Success
			response
					.status(200)
					.set(
							{
								'Access-Control-Allow-Origin': '*',
								'Access-Control-Allow-Credentials': true,
								'Access-Control-Expose-Headers': 'Content-Range',
								'Content-Range': 'documents */' + count,
							})
					.send();
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
					.send();
	} catch (error) {
		// Error
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send();
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
exports.getDocumentsV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);

	let	startIndex = request.query.startIndex || 0;
	let	count = request.query.count;
	let	fullInfo = request.query.fullInfo || 0;

	// Catch errors
	try {
		// Get info
		let	[upToDate, totalCount, results, error] =
					await request.app.locals.documentStorage.collectionGetDocuments(documentStorageID, name, startIndex,
							count, fullInfo == 1);
		if (upToDate) {
			// Success
			let	range = (results.length > 0) ? startIndex + '-' + (parseInt(startIndex) + results.length - 1) : '*';
			let	contentRange = 'documents ' + range + '/' + totalCount;

			response
					.status(200)
					.set({
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Credentials': true,
						'Access-Control-Expose-Headers': 'Content-Range',
						'Content-Range': contentRange,
					})
					.send(results);
		} else if (!error)
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};
