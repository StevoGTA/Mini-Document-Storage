//
//  MDSRemoteStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 1/14/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSRemoteStorage
public class MDSRemoteStorage : MDSDocumentStorage {

	// MARK: MDSDocumentStorage implementation
	public var id: String = UUID().uuidString

	//------------------------------------------------------------------------------------------------------------------
	public func extraValue<T>(for key :String) -> T? {
		// Not yet implemented
		fatalError("extraValue(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func store<T>(extraValue :T?, for key :String) {
		// Not yet implemented
		fatalError("store(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
			-> T {
		// Not yet implemented
		fatalError("newDocument(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Not yet implemented
		fatalError("document(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date {
		// Not yet implemented
		fatalError("creationDate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func modificationDate(for document :MDSDocument) -> Date {
		// Not yet implemented
		fatalError("modificationDate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func value(for property :String, in document :MDSDocument) -> Any? {
		// Not yet implemented
		fatalError("value(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Not yet implemented
		fatalError("date(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Not yet implemented
		fatalError("set(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ document :MDSDocument) {
		// Not yet implemented
		fatalError("remove(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Not yet implemented
		fatalError("enumerate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Not yet implemented
		fatalError("enumerate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Not yet implemented
		fatalError("batch(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			values :[String], isUpToDate :Bool, includeSelector :String,
			includeProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) {
		// Not yet implemented
		fatalError("registerCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// Not yet implemented
		fatalError("queryCollectionDocumentCount(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Not yet implemented
		fatalError("enumerateCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
		// Not yet implemented
		fatalError("registerIndex(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Not yet implemented
		fatalError("enumerateIndex(...) has not been implemented")
	}
}
