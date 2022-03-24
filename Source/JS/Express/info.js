//
//  info.js
//
//  Created by Stevo on 1/17/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Get
//	=> documentStorageID (path)
//	=> key (query) (can specify multiple)
//
//	<= [
//		"key" :String
//		...
//	   ]
exports.getV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	keys = request.query.key;

	// Validate input
	if (!keys) {
		// Must specify keys
		response
				.status(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing key(s)'})
		
		return;
	}

	// Catch errors
	try {
		// Get info
		let	results = await request.app.locals.documentStorage.infoGet(documentStorageID, keys);

		response
				.status(200)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send(results);
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
// MARK: Set
//	=> documentStorageID (path)
//	=> json (body)
//		[
//			"key" :String
//			...
//		]
exports.setV1 = async (request, response) => {
	// Setup
	let	documentStorageID = request.params.documentStorageID.replace(/%2B/g, '+').replace(/_/g, '/');

	let	info = request.body;

	// Validate input
	if (!info || (Object.keys(info).length == 0)) {
		// Must specify info
		response
				.status(400)
				.set({'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Credentials': true})
				.send({message: 'missing info'});

		return;
	}

	// Catch errors
	try {
		// Set info
		await request.app.locals.documentStorage.infoSet(documentStorageID, info);
		response
				.status(200)
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
