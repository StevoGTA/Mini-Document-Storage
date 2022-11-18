//
//  main.swift
//  Server (Swift)
//
//  Created by Stevo on 8/30/22.
//

import ArgumentParser
import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Server
struct Server : ParsableCommand {

	// MARK: Configuration
	static	var	configuration =
						CommandConfiguration(commandName: "server",
								abstract: "Server for Mini Documnet Storage.  Copyright © 2022, Stevo Brock",
								version: "1.0")

	// MARK: Arguments
	// Ephemeral
	@Flag(name: .shortAndLong, help: "Use Ephemeral Backing.")
	var	ephemeral = false

	// SQLite
	@Flag(name: .shortAndLong, help: "Use SQLite Backing.")
	var	sqlite = false

	// MARK: Instance Methods
	//--------------------------------------------------------------------------------------------------------------
	func run() {
		// Setup HTTP Server
		let	httpServer = VaporHTTPServer(port: 34343, maxBodySize: 1_000_000_000)

		// Setup MDS
		httpServer.setupMDSEndpoints()
		if self.ephemeral {
			// Ephemeral
			let	documentStorage = MDSEphemeral()

			MDSHTTPServices.register(documentStorage: documentStorage, for: "Sandbox")
		} else if self.sqlite {
			// SQLite
			let	libraryFolder = FileManager.default.folder(for: .libraryDirectory)
			let	applicationFolder = libraryFolder.folder(withSubPath: "Mini Document Storage Test Server (Swift)")
			try! FileManager.default.create(applicationFolder)

			let	documentStorage = try! MDSSQLite(in: applicationFolder)

			MDSHTTPServices.register(documentStorage: documentStorage, for: "Sandbox")
		} else {
			// You fool!
			print("Must specify one of --ephemeral or --sqlite")

			return
		}

		// Log
		print("Server listening on port 34343")

		// Loop forever
		dispatchMain()
	}
}
Server.main()
