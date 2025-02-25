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

	private	let	relevantProperties: Set<String>
	private	let	documentIsIncludedProc :MDSDocument.IsIncludedProc
	private	let	checkRelevantProperties :Bool
	private	let	isIncludedInfo :[String : Any]

	private	var	lastRevision :Int

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String],
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc, checkRelevantProperties :Bool,
			isIncludedInfo :[String : Any], lastRevision :Int) {
		// Store
		self.name = name
		self.documentType = documentType

		self.relevantProperties = Set<String>(relevantProperties)
		self.documentIsIncludedProc = documentIsIncludedProc
		self.checkRelevantProperties = checkRelevantProperties
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
			if !self.checkRelevantProperties || ($0.changedProperties == nil) ||
					!self.relevantProperties.intersection($0.changedProperties!).isEmpty {
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
