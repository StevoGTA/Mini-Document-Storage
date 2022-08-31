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
	func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String)
	func associationUpdate<T : MDSDocument, U : MDSDocument>(for name :String,
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)])
	func associationGet(for name :String) -> [(fromDocumentID :String, toDocumentID :String)]
	func associationIterate<T : MDSDocument, U : MDSDocument>(for name :String, from document :T,
			proc :(_ document :U) -> Void)
	func associationIterate<T : MDSDocument, U : MDSDocument>(for name :String, to document :U,
			proc :(_ document :T) -> Void)

//	func associationGetValue<T : MDSDocument, U>(for name :String, to document :T,
//			summedFromCachedValueWithName cachedValueName :String) -> U

	func cacheRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)])

	func collectionRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool)
	func collectionGetDocumentCount(for name :String) -> Int
	func collectionIterate<T : MDSDocument>(name :String, proc :(_ document : T) -> Void)

	func documentCreate<T : MDSDocument>(_ proc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T) -> T

	func document<T : MDSDocument>(for documentID :String) -> T?
	func iterate<T : MDSDocument>(proc :(_ document : T) -> Void)
	func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void)

	func creationDate(for document :MDSDocument) -> Date
	func modificationDate(for document :MDSDocument) -> Date

	func value(for property :String, of document :MDSDocument) -> Any?
	func data(for property :String, of document :MDSDocument) -> Data?
	func date(for property :String, of document :MDSDocument) -> Date?
	func set<T : MDSDocument>(_ value :Any?, for property :String, of document :T)

	func attachmentInfoMap(for document :MDSDocument) -> MDSDocument.AttachmentInfoMap
	func attachmentContent<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo) -> Data?
	func attachmentAdd<T : MDSDocument>(to document :T, type :String, info :[String : Any], content :Data)
	func attachmentUpdate<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo,
			updatedInfo :[String : Any], updatedContent :Data)
	func attachmentRemove<T : MDSDocument>(from document :T, attachmentInfo :MDSDocument.AttachmentInfo)

	func remove(_ document :MDSDocument)

	func indexRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String])
	func indexIterate<T : MDSDocument>(name :String, keys :[String], proc :(_ key :String, _ document :T) -> Void)

	func info(for keys :[String]) -> [String : String]
	func set(_ info :[String : String])
	func remove(keys :[String])

	func batch(_ proc :() throws -> MDSBatchResult) rethrows

	func registerDocumentChangedProc(documentType :String, proc :@escaping MDSDocument.ChangedProc)

	func ephemeralValue<T>(for key :String) -> T?
	func store<T>(ephemeralValue :T?, for key :String)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage extension
extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(fromDocumentType :String, toDocumentType :String) {
		// Register association
		associationRegister(named: associationName(fromDocumentType: fromDocumentType, toDocumentType: toDocumentType),
				fromDocumentType :fromDocumentType, toDocumentType :toDocumentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate<T : MDSDocument, U : MDSDocument>(
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)]) {
		// Update association
		associationUpdate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				updates: updates)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(fromDocumentType :String, toDocumentType :String) ->
			[(fromDocumentID :String, toDocumentID :String)] {
		// Get associations
		return associationGet(for: associationName(fromDocumentType: fromDocumentType, toDocumentType: toDocumentType))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(from document :T, proc :(_ document :U) -> Void) {
		// Iterate association
		associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(to document :U, proc :(_ document :T) -> Void) {
		// Iterate association
		associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationDocuments<T : MDSDocument, U : MDSDocument>(for name :String? = nil, from document :T) ->
			[U] {
		// Setup
		var	documents = [U]()

		// Iterate
		associationIterate(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document) { (document :U) in documents.append(document) }

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationDocuments<T : MDSDocument, U : MDSDocument>(for name :String? = nil, to document :U) -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate
		associationIterate(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document) { documents.append($0 as! T) }

		return documents
	}

//	//------------------------------------------------------------------------------------------------------------------
//	public func associationGetValue<T : MDSDocument, U>(fromDocumentType :String, to document :T,
//			summedFromCachedValueWithName name :String) -> U {
//		// Return value
//		return associationGetValue(
//				for: associationName(fromDocumentType: fromDocumentType, toDocumentType: T.documentType),
//				to: document, summedFromCachedValueWithName: name)
//	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister<T : MDSDocument>(version :Int = 1, relevantProperties :[String] = [],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)]) {
		// Register cache
		cacheRegister(named: T.documentType, version: version, relevantProperties: relevantProperties,
				valuesInfos: valuesInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister<T : MDSDocument>(named name :String, version :Int = 1, relevantProperties :[String],
			isUpToDate :Bool = false, isIncludedSelector :String = "", isIncludedSelectorInfo :[String : Any] = [:],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Register collection
		collectionRegister(named: name, version: version, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
				isIncludedSelectorInfo: isIncludedSelectorInfo, isIncludedProc: isIncludedProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T : MDSDocument>(forCollectionNamed name :String) -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate
		collectionIterate(name: name) { (t :T) in documents.append(t) }

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate<T : MDSDocument>() -> T { documentCreate() { T(id: $0, documentStorage: $1) } }

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
	public func indexRegister<T : MDSDocument>(named name :String, version :Int = 1, relevantProperties :[String],
			isUpToDate :Bool = false, keysSelector :String = "", keysSelectorInfo :[String : Any] = [:],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Register index
		indexRegister(named: name, version: version, relevantProperties: relevantProperties, isUpToDate: isUpToDate,
				keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo, keysProc: keysProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentMap<T : MDSDocument>(forIndexNamed name :String, keys :[String]) -> [String : T] {
		// Setup
		var	documentMap = [String : T]()

		indexIterate(name: name, keys: keys) { (key :String, document :T) in documentMap[key] = document }

		return documentMap
	}

	//------------------------------------------------------------------------------------------------------------------
	public func string(for key :String) -> String? { info(for: [key])[key] }

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func associationName(fromDocumentType :String, toDocumentType :String) -> String {
		// Return
		return "\(fromDocumentType)To\(toDocumentType.capitalizingFirstLetter)"
	}
}
