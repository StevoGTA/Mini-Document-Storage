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

	// MARK: Types
	typealias DocumentInfo<U> = (document :MDSDocument, revision :Int, value :U)

	// MARK: Properties
	var	name :String { get }
	var	documentType :String { get }
	var	relevantProperties :Set<String> { get }
	var	lastRevision :Int { get }

	// MARK: Instance methods
	func update<U>(_ documentInfo :DocumentInfo<U>, changedProperties :[String]?) ->
			(keys :[String]?, lastRevision :Int?)
	func bringUpToDate<U>(_ documentInfos :[DocumentInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSIndexSpecialized
class MDSIndexSpecialized<T : MDSDocument> : MDSIndex {

	// MARK: MDSIndex implementation
	let	name :String
	let	relevantProperties :Set<String>

	var	documentType :String { return T.documentType }
	var	lastRevision :Int

	func update<U>(_ documentInfo :DocumentInfo<U>, changedProperties :[String]?) ->
			(keys :[String]?, lastRevision :Int?) {
		// Must be up to date except for this document
		guard documentInfo.revision == (self.lastRevision + 1) else { return (nil, nil) }

		// Update
		self.lastRevision = documentInfo.revision

		// Check if there is something to do
		guard (changedProperties == nil) || !self.relevantProperties.intersection(changedProperties!).isEmpty else
				{ return (nil, self.lastRevision) }

		return (self.keysProc(documentInfo.document as! T), self.lastRevision)
	}

	func bringUpToDate<U>(_ documentInfos :[DocumentInfo<U>]) ->
			(keysInfos :[(keys :[String], value :U)], lastRevision :Int) {
		// Compose results
		var	keysInfos = [(keys :[String], value :U)]()
		documentInfos.forEach() {
			// Update keys info
			keysInfos.append((self.keysProc($0.document as! T), $0.value))

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		return (keysInfos, self.lastRevision)
	}

	// MARK: Properties
	private	let	keysProc :MDSDocument.KeysProc<T>

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, relevantProperties :[String], lastRevision :Int, keysProc :@escaping MDSDocument.KeysProc<T>) {
		// Store
		self.name = name
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.keysProc = keysProc
	}
}
