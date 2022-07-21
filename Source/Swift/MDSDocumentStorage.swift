//
//  MDSDocumentStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatchResult
public enum MDSBatchResult {
	case commit
	case cancel
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSValueType
public enum MDSValueType : String {
	case integer = "integer"
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSAssociationAction
public enum MDSAssociationAction : String {
	case add = "add"
	case remove = "remove"
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage protocol
public protocol MDSDocumentStorage : AnyObject {

	// MARK: Properties
	var	id :String { get }

	// MARK: Instance methods
	func info(for keys :[String]) -> [String : String]
	func set(_ info :[String : String])
	func remove(keys :[String])

	func ephemeralValue<T>(for key :String) -> T?
	func store<T>(ephemeralValue :T?, for key :String)

	func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T) -> T

	func document<T : MDSDocument>(for documentID :String) -> T?
	func iterate<T : MDSDocument>(proc :(_ document : T) -> Void)
	func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void)

	func creationDate(for document :MDSDocument) -> Date
	func modificationDate(for document :MDSDocument) -> Date

	func value(for property :String, in document :MDSDocument) -> Any?
	func data(for property :String, in document :MDSDocument) -> Data?
	func date(for property :String, in document :MDSDocument) -> Date?
	func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T)

	func attachmentInfoMap(for document :MDSDocument) -> MDSDocument.AttachmentInfoMap
	func attachmentContent<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo) -> Data?
	func addAttachment<T : MDSDocument>(for document :T, type :String, info :[String : Any], content :Data)
	func updateAttachment<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo,
			updatedInfo :[String : Any], updatedContent :Data)
	func removeAttachment<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo)

	func batch(_ proc :() throws -> MDSBatchResult) rethrows

	func remove(_ document :MDSDocument)

	func registerAssociation(named name :String, fromDocumentType :String, toDocumentType :String)
	func updateAssociation<T : MDSDocument, U : MDSDocument>(for name :String,
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)])
	func iterateAssociation<T : MDSDocument, U : MDSDocument>(for name :String, from document :T,
			proc :(_ document :U) -> Void)
	func iterateAssociation<T : MDSDocument, U : MDSDocument>(for name :String, to document :U,
			proc :(_ document :T) -> Void)

//	func retrieveAssociationValue<T : MDSDocument, U>(for name :String, to document :T,
//			summedFromCachedValueWithName cachedValueName :String) -> U

	func registerCache<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)])

	func registerCollection<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool)
	func documentCountForCollection(named name :String) -> Int
	func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void)

	func registerIndex<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String])
	func iterateIndex<T : MDSDocument>(name :String, keys :[String], proc :(_ key :String, _ document :T) -> Void)

	func registerDocumentChangedProc(documentType :String, proc :@escaping MDSDocument.ChangedProc)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage extension
extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func string(for key :String) -> String? { info(for: [key])[key] }
	
	//------------------------------------------------------------------------------------------------------------------
	public func newDocument<T : MDSDocument>() -> T { newDocument() { T(id: $0, documentStorage: $1) } }

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>() -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate all documents
		iterate(proc: { (document :T) -> Void in documents.append(document) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>(for documentIDs :[String]) -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate documents for document ids
		iterate(documentIDs: documentIDs, proc: { (document :T) -> Void in documents.append(document) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerAssociation(fromDocumentType :String, toDocumentType :String) {
		// Register association
		registerAssociation(named: associationName(fromDocumentType: fromDocumentType, toDocumentType: toDocumentType),
				fromDocumentType :fromDocumentType, toDocumentType :toDocumentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func updateAssociation<T : MDSDocument, U : MDSDocument>(
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)]) {
		// Update association
		updateAssociation(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				updates: updates)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateAssociation<T : MDSDocument, U : MDSDocument>(from document :T, proc :(_ document :U) -> Void) {
		// Iterate association
		iterateAssociation(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateAssociation<T : MDSDocument, U : MDSDocument>(to document :U, proc :(_ document :T) -> Void) {
		// Iterate association
		iterateAssociation(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentsAssociated<T : MDSDocument, U : MDSDocument>(for name :String? = nil, from document :T) ->
			[U] {
		// Setup
		var	documents = [U]()

		// Iterate
		iterateAssociation(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document) { (document :U) in documents.append(document) }

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentsAssociated<T : MDSDocument, U : MDSDocument>(for name :String? = nil, to document :U) -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate
		iterateAssociation(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document) { documents.append($0 as! T) }

		return documents
	}

//	//------------------------------------------------------------------------------------------------------------------
//	public func retrieveAssociationValue<T : MDSDocument, U>(fromDocumentType :String, to document :T,
//			summedFromCachedValueWithName name :String) -> U {
//		// Return value
//		return retrieveAssociationValue(
//				for: associationName(fromDocumentType: fromDocumentType, toDocumentType: T.documentType),
//				to: document, summedFromCachedValueWithName: name)
//	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCache<T : MDSDocument>(version :Int = 1, relevantProperties :[String] = [],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)]) {
		// Register cache
		registerCache(named: T.documentType, version: version, relevantProperties: relevantProperties,
				valuesInfos: valuesInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :Int = 1, relevantProperties :[String],
			isUpToDate :Bool = false, isIncludedSelector :String = "", isIncludedSelectorInfo :[String : Any] = [:],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Register collection
		registerCollection(named: name, version: version, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
				isIncludedSelectorInfo: isIncludedSelectorInfo, isIncludedProc: isIncludedProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T : MDSDocument>(forCollectionNamed name :String) -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate
		iterateCollection(name: name) { (t :T) in documents.append(t) }

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :Int = 1, relevantProperties :[String],
			isUpToDate :Bool = false, keysSelector :String = "", keysSelectorInfo :[String : Any] = [:],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Register index
		registerIndex(named: name, version: version, relevantProperties: relevantProperties, isUpToDate: isUpToDate,
				keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo, keysProc: keysProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentMap<T : MDSDocument>(forIndexNamed name :String, keys :[String]) -> [String : T] {
		// Setup
		var	documentMap = [String : T]()

		iterateIndex(name: name, keys: keys) { (key :String, document :T) in documentMap[key] = document }

		return documentMap
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func associationName(fromDocumentType :String, toDocumentType :String) -> String {
		// Return
		return "\(fromDocumentType)To\(toDocumentType.capitalizingFirstLetter)"
	}
}
