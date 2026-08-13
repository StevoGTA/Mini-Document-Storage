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

			var	lastRevision :Int

	private	let	relevantProperties: Set<String>?
	private	let	documentIsIncludedProc :MDSDocument.IsIncludedProc
	private	let	isIncludedInfo :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String]?,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc, isIncludedInfo :[String : Any],
			lastRevision :Int) {
		// Validate - nil means "always evaluate"; an empty array is a programmer error
		if relevantProperties?.isEmpty ?? false {
			// Empty
			fatalError("MDSCollection \(name): relevantProperties is empty - pass nil to always evaluate")
		}

		// Store
		self.name = name
		self.documentType = documentType

		self.relevantProperties = relevantProperties.map({ Set<String>($0) })
		self.documentIsIncludedProc = documentIsIncludedProc
		self.isIncludedInfo = isIncludedInfo

		self.lastRevision = lastRevision
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	static func == (lhs :MDSCollection, rhs :MDSCollection) -> Bool { lhs.name == rhs.name }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) -> (includedIDs :[U]?, notIncludedIDs :[U]?, lastRevision :Int?) {
		// Compose results
		var	includedIDs = [U]()
		var	notIncludedIDs = [U]()
		var	lastRevision :Int?
		updateInfos.forEach() {
			// Check if there is something to do
			if (self.relevantProperties == nil) || ($0.changedProperties == nil) ||
					!self.relevantProperties!.intersection($0.changedProperties!).isEmpty {
				// Query
				if self.documentIsIncludedProc(self.documentType, $0.document, self.isIncludedInfo) {
					// Included
					includedIDs.append($0.id)
				} else {
					// Not included
					notIncludedIDs.append($0.id)
				}
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
			lastRevision = self.lastRevision
		}

		return (!includedIDs.isEmpty ? includedIDs : nil, !notIncludedIDs.isEmpty ? notIncludedIDs : nil, lastRevision)
	}
}
