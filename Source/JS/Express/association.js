//
//  association.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
exports.registerV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
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
// MARK: Update
exports.updateV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
exports.getDocumentsV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);
	let	fromDocumentID = request.query.fromID ? decodeURIComponent(request.query.fromID) : null;
	let	toDocumentID = request.query.toID ? decodeURIComponent(request.query.toID) : null;
	let	startIndex = request.query.startIndex || 0;
	let	count = request.query.count;
	let	fullInfo = request.query.fullInfo || 0;

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
						'Access-Control-Expose-Headers': 'Content-Range',
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Association Value
exports.getValueV1 = async (request, response) => {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);
	let	action = request.params.action;

	let	fromDocumentID = decodeURIComponent(request.query.fromID);
	let	cacheName = decodeURIComponent(request.query.cacheName);
	let	cachedValueName = decodeURIComponent(request.query.cachedValueName);

	// Catch errors
	try {
		// Get info
		let	[upToDate, value, error] =
					await request.app.locals.documentStorage.associationGetValue(documentStorageID, name, action,
							fromDocumentID, cacheName, cachedValueName);
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}; 
