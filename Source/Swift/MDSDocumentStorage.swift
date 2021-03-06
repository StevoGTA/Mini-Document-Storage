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
// MARK: - MDSDocumentStorage protocol
public protocol MDSDocumentStorage : class {

	// MARK: Properties
	var	id :String { get }

	// MARK: Instance methods
	func info(for keys :[String]) -> [String : String]
	func set(_ info :[String : String])
	func remove(keys :[String])

	func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T) -> T

	func document<T : MDSDocument>(for documentID :String) -> T?

	func creationDate(for document :MDSDocument) -> Date
	func modificationDate(for document :MDSDocument) -> Date

	func value(for property :String, in document :MDSDocument) -> Any?
	func data(for property :String, in document :MDSDocument) -> Data?
	func date(for property :String, in document :MDSDocument) -> Date?
	func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T)

	func remove(_ document :MDSDocument)

	func iterate<T : MDSDocument>(proc :(_ document : T) -> Void)
	func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void)

	func batch(_ proc :() throws -> MDSBatchResult) rethrows

	func registerCollection<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool)
	func queryCollectionDocumentCount(name :String) -> Int
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
		iterateCollection(name: name) { documents.append($0) }

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
}
