//
//  MDSCollection.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
protocol MDSCollection {

	// MARK: Types
	typealias BringUpToDateDocumentInfo<U> = (document :MDSDocument, revision :Int, value :U)
	typealias UpdateDocumentInfo<U> = (document :MDSDocument, revision :Int, value :U, changedProperties :[String]?)

	// MARK: Properties
	var	name :String { get }
	var	documentType :String { get }
	var	relevantProperties :Set<String> { get }
	var	lastRevision :Int { get }

	// MARK: Instance methods
	func update<U>(_ documentInfos :[(document :MDSDocument, revision :Int, value :U, changedProperties :[String]?)]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int)
	func bringUpToDate<U>(_ documentInfos :[BringUpToDateDocumentInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSCollectionSpecialized
class MDSCollectionSpecialized<T : MDSDocument> : MDSCollection {

	// MARK: MDSCollection implementation
	let	name :String
	let	relevantProperties: Set<String>

	var	documentType :String { return T.documentType }
	var	lastRevision :Int

	func update<U>(_ documentInfos :[UpdateDocumentInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int) {
		// Compose results
		var	includedValues = [U]()
		var	notIncludedValues = [U]()
		documentInfos.forEach() {
			// Check if there is something to do
			guard ($0.changedProperties == nil) || !self.relevantProperties.intersection($0.changedProperties!).isEmpty
					else { return }

			// Query
			if self.includeProc($0.document as! T, self.info) {
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

	func bringUpToDate<U>(_ documentInfos :[BringUpToDateDocumentInfo<U>]) ->
			(includedValues :[U], notIncludedValues :[U], lastRevision :Int) {
		// Compose results
		var	includedValues = [U]()
		var	notIncludedValues = [U]()
		documentInfos.forEach() {
			// Query
			if self.includeProc($0.document as! T, self.info) {
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

	// MARK: Properties
	private	let	includeProc :(_ document :T, _ info :[String : Any]) -> Bool
	private	let	info :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, relevantProperties :[String], lastRevision :Int,
			includeProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool, info :[String : Any]) {
		// Store
		self.name = name
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.includeProc = includeProc
		self.info = info
	}
}
