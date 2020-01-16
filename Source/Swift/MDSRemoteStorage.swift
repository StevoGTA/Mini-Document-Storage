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
class MDSRemoteStorage : MDSDocumentStorage {

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>(creationProc :MDSDocument.CreationProc<T>) -> T {
		// Not yet implemented
		fatalError("newDocument(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for documentID :String) -> T? {
		// Not yet implemented
		fatalError("document(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func creationDate(for document :MDSDocument) -> Date {
		// Not yet implemented
		fatalError("creationDate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func modificationDate(for document :MDSDocument) -> Date {
		// Not yet implemented
		fatalError("modificationDate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func value(for property :String, in document :MDSDocument) -> Any? {
		// Not yet implemented
		fatalError("value(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func date(for property :String, in document :MDSDocument) -> Date? {
		// Not yet implemented
		fatalError("date(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for property :String, in document :MDSDocument) {
		// Not yet implemented
		fatalError("set(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(_ document :MDSDocument) {
		// Not yet implemented
		fatalError("remove(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(proc :MDSDocument.ApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(documentIDs :[String], proc :MDSDocument.ApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerate(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> MDSBatchResult) {
		// Not yet implemented
		fatalError("batch(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			values :[String], isUpToDate :Bool, includeSelector :String,
			includeProc :@escaping MDSDocument.IncludeProc<T>) {
		// Not yet implemented
		fatalError("registerCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func queryCollectionDocumentCount(name :String) -> UInt {
		// Not yet implemented
		fatalError("queryCollectionDocumentCount(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerateCollection<T : MDSDocument>(name :String, proc :MDSDocument.ApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerateCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping MDSDocument.KeysProc<T>) {
		// Not yet implemented
		fatalError("registerIndex(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerateIndex<T : MDSDocument>(name :String, keys :[String], proc :MDSDocument.IndexApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerateIndex(...) has not been implemented")
	}
}
