//
//  MDSIndex.swift
//  Mini Document Storage
//
//  Created by Stevo on 11/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSIndex
class MDSIndex : Equatable {

	// MARK: Properties
			let	name :String
			let	documentType :String
			let	relevantProperties :Set<String>

			var	lastRevision :Int

	private	let	keysProc :MDSDocument.KeysProc
	private	let	keysInfo :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String], lastRevision :Int,
			keysProc :@escaping MDSDocument.KeysProc, keysInfo :[String : Any]) {
		// Store
		self.name = name
		self.documentType = documentType
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.keysProc = keysProc
		self.keysInfo = keysInfo
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	static func == (lhs :MDSIndex, rhs :MDSIndex) -> Bool { lhs.name == rhs.name }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) -> (keysInfos :[(keys :[String], value :U)], lastRevision :Int)? {
		// Compose results
		var	keysInfos = [(keys :[String], value :U)]()
		updateInfos.forEach() {
			// Check if there is something to do
			if ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty {
				// Update keys info
				keysInfos.append((self.keysProc($0.document, self.keysInfo), $0.value))
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		if !keysInfos.isEmpty {
			// Have info
			return (keysInfos, self.lastRevision)
		} else {
			// No info
			return nil
		}
	}
}
