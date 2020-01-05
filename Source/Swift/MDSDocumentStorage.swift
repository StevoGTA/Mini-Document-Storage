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

	// MARK: Instance methods
	func newDocument<T : MDSDocument>(creationProc :MDSDocument.CreationProc<T>) -> T

	func document<T : MDSDocument>(for documentID :String) -> T?

	func creationDate(for document :MDSDocument) -> Date
	func modificationDate(for document :MDSDocument) -> Date

	func value(for property :String, in document :MDSDocument) -> Any?
	func date(for property :String, in document :MDSDocument) -> Date?
	func set(_ value :Any?, for property :String, in document :MDSDocument)

	func remove(_ document :MDSDocument)

	func enumerate<T : MDSDocument>(proc :MDSDocument.ApplyProc<T>)
	func enumerate<T : MDSDocument>(documentIDs :[String], proc :MDSDocument.ApplyProc<T>)

	func batch(_ proc :() -> MDSBatchResult)

	func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			info :[String : Any], isUpToDate :Bool, includeSelector :String,
			includeProc :@escaping MDSDocument.IncludeProc<T>)
	func queryCollectionDocumentCount(name :String) -> UInt
	func enumerateCollection<T : MDSDocument>(name :String, proc :MDSDocument.ApplyProc<T>)

	func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping MDSDocument.KeysProc<T>)
	func enumerateIndex<T : MDSDocument>(name :String, keys :[String], proc :MDSDocument.IndexApplyProc<T>)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage extension
extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>() -> T { return newDocument() { return T(id: $0, documentStorage: $1) } }

	//------------------------------------------------------------------------------------------------------------------
	func documents<T :MDSDocument>() -> [T] {
		// Setup
		var	documents = [T]()

		// Enumerate all documents
		enumerate(proc: { (document :T) -> Void in documents.append(document) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents<T :MDSDocument>(for documentIDs :[String]) -> [T] {
		// Setup
		var	documents = [T]()

		// Enumerate documents for document ids
		enumerate(documentIDs: documentIDs, proc: { (document :T) -> Void in documents.append(document) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection<T : MDSDocument>(named name :String, version :UInt = 1, relevantProperties :[String],
			info :[String : Any] = [:], isUpToDate :Bool = true, includeSelector :String = "",
			includeProc :@escaping MDSDocument.IncludeProc<T>) {
		// Register collection
		registerCollection(named: name, version: version, relevantProperties: relevantProperties,
				info: info, isUpToDate: isUpToDate, includeSelector: includeSelector, includeProc: includeProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex<T : MDSDocument>(named name :String, version :UInt = 1, relevantProperties :[String],
			isUpToDate :Bool = true, keysSelector :String = "", keysProc :@escaping MDSDocument.KeysProc<T>) {
		// Register index
		registerIndex(named: name, version: version, relevantProperties: relevantProperties, isUpToDate: isUpToDate,
				keysSelector: keysSelector, keysProc: keysProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentMap<T : MDSDocument>(forIndexNamed name :String, keys :[String]) -> [String : T] {
		// Setup
		var	documentMap = [String : T]()

		enumerateIndex(name: name, keys: keys) { (key :String, document :T) in documentMap[key] = document }

		return documentMap
	}
}
