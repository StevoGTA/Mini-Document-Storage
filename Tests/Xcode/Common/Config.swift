//
//  Config.swift
//  Common
//
//  Created by Stevo on 2/22/22.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Config
class Config {

	// MARK: Properties
	static	let	shared = Config()

			let	httpEndpointClient = HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 1138)
			let	documentStorageID = "Sandbox"
}
