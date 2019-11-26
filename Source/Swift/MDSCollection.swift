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
	typealias DocumentInfo<U> = (document :MDSDocument, revision :Int, value :U)

	// MARK: Properties
	var	name :String { get }
	var	documentType :String { get }
	var	relevantProperties :Set<String> { get }
	var	lastRevision :Int { get }

	// MARK: Instance methods
	func update<U>(_ documentInfo :DocumentInfo<U>, changedProperties :[String]?) ->
			(included :Bool?, lastRevision :Int?)
	func bringUpToDate<U>(_ documentInfos :[DocumentInfo<U>]) ->
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

	func update<U>(_ documentInfo :DocumentInfo<U>, changedProperties :[String]?) ->
			(included :Bool?, lastRevision :Int?) {
		// Must be up to date except for this document
		guard documentInfo.revision == (self.lastRevision + 1) else { return (nil, nil) }

		// Update
		self.lastRevision = documentInfo.revision

		// Check if there is something to do
		guard (changedProperties == nil) || !self.relevantProperties.intersection(changedProperties!).isEmpty else
				{ return (nil, self.lastRevision) }

		return (self.includeProc(documentInfo.document as! T, self.info), self.lastRevision)
	}

	func bringUpToDate<U>(_ documentInfos :[DocumentInfo<U>]) ->
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
	private	let	includeProc :MDSDocument.IncludeProc<T>
	private	let	info :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, relevantProperties :[String], lastRevision :Int,
			includeProc :@escaping MDSDocument.IncludeProc<T>, info :[String : Any]) {
		// Store
		self.name = name
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.includeProc = includeProc
		self.info = info
	}
}
