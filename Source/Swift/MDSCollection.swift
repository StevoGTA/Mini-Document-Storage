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
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) -> (includedIDs :[U], notIncludedIDs :[U], lastRevision :Int)? {
		// Compose results
		var	includedIDs = [U]()
		var	notIncludedIDs = [U]()
		updateInfos.forEach() {
			// Check if there is something to do
			if ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty {
				// Query
				if self.isIncludedProc(type(of: $0.document).documentType, $0.document, self.isIncludedInfo) {
					// Included
					includedIDs.append($0.id)
				} else {
					// Not included
					notIncludedIDs.append($0.id)
				}
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		return (!includedIDs.isEmpty || !notIncludedIDs.isEmpty) ?
				(includedIDs, notIncludedIDs, self.lastRevision) : nil
	}
}
