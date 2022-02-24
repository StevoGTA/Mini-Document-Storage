//
//  MDSIndex.swift
//  Mini Document Storage
//
//  Created by Stevo on 11/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSIndex
protocol MDSIndex {

	// MARK: Properties
	var	name :String { get }
	var	documentType :String { get }
	var	relevantProperties :Set<String> { get }
	var	lastRevision :Int { get }

	// MARK: Instance methods
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int)?
	func bringUpToDate<U>(_ bringUpToDateInfos :[MDSBringUpToDateInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSIndexSpecialized
class MDSIndexSpecialized<T : MDSDocument> : MDSIndex {

	// MARK: Properties
			let	name :String
			let	relevantProperties :Set<String>

			var	documentType :String { T.documentType }
			var	lastRevision :Int

	private	let	keysProc :(_ document :T) -> [String]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, relevantProperties :[String], lastRevision :Int,
			keysProc :@escaping (_ document :T) -> [String]) {
		// Store
		self.name = name
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.keysProc = keysProc
	}

	// MARK: MDSIndex implementation
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int)? {
		// Compose results
		var	keysInfos = [(keys :[String], value :U)]()
		updateInfos.forEach() {
			// Check if there is something to do
			if ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty {
				// Update keys info
				keysInfos.append((self.keysProc($0.document as! T), $0.value))
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

	//------------------------------------------------------------------------------------------------------------------
	func bringUpToDate<U>(_ bringUpToDateInfos :[MDSBringUpToDateInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int) {
		// Compose results
		var	keysInfos = [(keys :[String], value :U)]()
		bringUpToDateInfos.forEach() {
			// Update keys info
			keysInfos.append((self.keysProc($0.document as! T), $0.value))

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		return (keysInfos, self.lastRevision)
	}
}
