//
//  MDSCollection.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSCollection
class MDSCollection : Equatable {

	// MARK: Properties
			let	name :String
			let	documentType :String
			let	relevantProperties: Set<String>

			var	lastRevision :Int

	private	let	isIncludedProc :MDSDocument.IsIncludedProc
	private	let	isIncludedInfo :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String], lastRevision :Int,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc, isIncludedInfo :[String : Any]) {
		// Store
		self.name = name
		self.documentType = documentType
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.isIncludedInfo = isIncludedInfo
		self.isIncludedProc = isIncludedProc
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	static func == (lhs :MDSCollection, rhs :MDSCollection) -> Bool { lhs.name == rhs.name }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int)? {
		// Compose results
		var	includedValues = [U]()
		var	notIncludedValues = [U]()
		updateInfos.forEach() {
			// Check if there is something to do
			if ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty {
				// Query
				if self.isIncludedProc($0.document, self.isIncludedInfo) {
					// Included
					includedValues.append($0.value)
				} else {
					// Not included
					notIncludedValues.append($0.value)
				}
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		return (!includedValues.isEmpty || !notIncludedValues.isEmpty) ?
				(includedValues, notIncludedValues, self.lastRevision) : nil
	}
}
