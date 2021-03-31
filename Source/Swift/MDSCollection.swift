//
//  MDSCollection.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSCollection
protocol MDSCollection {

	// MARK: Properties
	var	name :String { get }
	var	documentType :String { get }
	var	relevantProperties :Set<String> { get }
	var	lastRevision :Int { get }

	// MARK: Instance methods
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int)
	func bringUpToDate<U>(_ bringUpToDateInfos :[MDSBringUpToDateInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSCollectionSpecialized
class MDSCollectionSpecialized<T : MDSDocument> : MDSCollection {

	// MARK: Properties
			let	name :String
			let	relevantProperties: Set<String>

			var	documentType :String { T.documentType }
			var	lastRevision :Int

	private	let	isIncludedProc :(_ document :T) -> Bool

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, relevantProperties :[String], lastRevision :Int,
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Store
		self.name = name
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.isIncludedProc = isIncludedProc
	}

	// MARK: MDSCollection implementation
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int) {
		// Compose results
		var	includedValues = [U]()
		var	notIncludedValues = [U]()
		updateInfos.forEach() {
			// Check if there is something to do
			if ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty {
				// Query
				if self.isIncludedProc($0.document as! T) {
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

		return (includedValues, notIncludedValues, self.lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	func bringUpToDate<U>(_ bringUpToDateInfos :[MDSBringUpToDateInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int) {
		// Compose results
		var	includedValues = [U]()
		var	notIncludedValues = [U]()
		bringUpToDateInfos.forEach() {
			// Query
			if self.isIncludedProc($0.document as! T) {
				// Included
				includedValues.append($0.value)
			} else {
				// Not included
				notIncludedValues.append($0.value)
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, $0.revision)
		}

		return (includedValues, notIncludedValues, self.lastRevision)
	}
}
