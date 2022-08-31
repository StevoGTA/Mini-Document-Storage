//
//  internal.js
//
//  Created by Stevo on 8/24/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

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
	let	documentStorageID = request.params.documentStorageID.replace(/_/g, '/');	// Convert back to /
	let	info = request.body;

	// Catch errors
	try {
		// Set info
		let	error = await request.app.locals.documentStorage.internalSet(documentStorageID, info);
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
