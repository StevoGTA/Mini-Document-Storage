//
//  MDSDocument.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

/*
	Still need data and error (NSError) based on HRCoder
		Need actual stored examples to match
*/

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument
public class MDSDocument : Hashable {

	// MARK: Procs
	public typealias ApplyProc<T : MDSDocument> = (_ document :T) -> Void
	public typealias CreationProc<T :MDSDocument> = (_ id :String, _ documentStorage :MDSDocumentStorage) -> T
	public typealias KeysProc<T :MDSDocument> = (_ document :T) -> [String]
	public typealias IncludeProc<T : MDSDocument> = (_ document :T, _ info :[String : Any]) -> Bool

	// MARK: Equatable implementation
	static	public	func == (lhs: MDSDocument, rhs: MDSDocument) -> Bool { return lhs.id == rhs.id }

	// MARK: Hashable implementation
	public func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

	// MARK: Properties
	class	var	documentType :String { return "" }

			var	creationDate :Date { return self.documentStorage.creationDate(for: self) }
			var	modificationDate :Date { return self.documentStorage.modificationDate(for: self) }

			var	id :String
			var	documentStorage: MDSDocumentStorage

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	required init(id :String, documentStorage :MDSDocumentStorage) {
		// Store
		self.id = id
		self.documentStorage = documentStorage
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func array<T>(for key :String) -> [T]? { return self.documentStorage.value(for: key, in: self) as? [T] }
	func set<T>(_ value :[T]?, for key :String) { self.documentStorage.set(value, for: key, in: self) }

	//------------------------------------------------------------------------------------------------------------------
	func bool(for key :String) -> Bool? { return self.documentStorage.value(for: key, in: self) as? Bool }
	func set(_ value :Bool?, for key :String) {
		// Check if different
		guard value != bool(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func date(for key :String) -> Date? { return self.documentStorage.date(for: key, in: self) }
	func set(_ value :Date?, for key :String) {
		// Check if different
		guard value != date(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func double(for key :String) -> Double? { return self.documentStorage.value(for: key, in: self) as? Double }
	func set(_ value :Double?, for key :String) {
		// Check if different
		guard value != double(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func int(for key :String) -> Int? { return self.documentStorage.value(for: key, in: self) as? Int }
	func set(_ value :Int?, for key :String) {
		// Check if different
		guard value != int(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func int64(for key :String) -> Int64? { return self.documentStorage.value(for: key, in: self) as? Int64 }
	func set(_ value :Int64?, for key :String) {
		// Check if different
		guard value != int64(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func uint(for key :String) -> UInt? { return self.documentStorage.value(for: key, in: self) as? UInt }
	func set(_ value :UInt?, for key :String) {
		// Check if different
		guard value != uint(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func map(for key :String) -> [String : Any]? { return self.documentStorage.value(for: key, in: self) as? [String : Any] }
	func set(_ value :[String : Any]?, for key :String) {
		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func string(for key :String) -> String? { return self.documentStorage.value(for: key, in: self) as? String }
	func set(_ value :String?, for key :String) {
		// Check if different
		guard value != string(for: key) else { return }

		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for key :String,
			creationProc :MDSDocument.CreationProc<T> = { return T(id: $0, documentStorage: $1) }) -> T? {
		// Retrieve document ID
		guard let documentID = string(for: key) else { return nil }

		return self.documentStorage.document(for: documentID)
	}
	func set<T : MDSDocument>(_ document :T?, for key :String) {
		// Check if different
		guard document?.id != string(for: key) else { return }

		// Set value
		self.documentStorage.set(document?.id, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents<T : MDSDocument>(for key :String,
			creationProc :MDSDocument.CreationProc<T> = { return T(id: $0, documentStorage: $1) }) -> [T]? {
		// Retrieve document ID
		guard let documentIDs :[String] = array(for: key) else { return nil }

		return self.documentStorage.documents(for: documentIDs)
	}
	func set<T : MDSDocument>(_ documents :[T]?, for key :String) {
		// Set value
		self.documentStorage.set(documents?.map({ $0.id }), for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentMap<T : MDSDocument>(for key :String) -> [String : T]? {
		// Retrieve document IDs map
		guard let storedMap = map(for: key) as? [String : String] else { return nil }

		let	documents :[T] = self.documentStorage.documents(for: Array(storedMap.values))
		guard documents.count == storedMap.count else { return nil }

		// Prepare map from document ID to document
		var	documentMap = [String : T]()
		documents.forEach() { documentMap[$0.id] = $0 }

		return storedMap.mapValues() { documentMap[$0]! }
	}
	func set<T : MDSDocument>(_ documentMap :[String : T]?, for key :String) {
		// Set value
		self.documentStorage.set(documentMap?.mapValues({ $0.id }), for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove() { self.documentStorage.remove(self) }
}
