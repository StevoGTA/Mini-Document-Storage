//
//  index.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Register
export async function registerV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	info = request.body;

	// Catch errors
	try {
		// Register index
		let	error = await request.app.locals.documentStorage.indexRegister(documentStorageID, info);
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
		console.error(error.stack);
		response
				.status(500)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({error: 'Internal error'});
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get Document Infos
export async function getDocumentsV1(request, response) {
	// Setup
	let	documentStorageID = decodeURIComponent(request.params.documentStorageID);
	let	name = decodeURIComponent(request.params.name);

	var	keys = request.query.key;
	if (typeof keys == 'string')
		keys = [keys];
	keys = keys.map(key => decodeURIComponent(key));

	let	fullInfo = request.query.fullInfo || 0;

	// Catch errors
	try {
		// Get Index Documents
		let	[upToDate, results, error] =
					await request.app.locals.documentStorage.indexGetDocuments(documentStorageID, name, keys,
							fullInfo == 1);
		if (upToDate)
			// Success
			response
					.status(200)
					.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
					.send(results);
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
}
