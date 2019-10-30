//
//  MDSDocument.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument
class MDSDocument : Hashable {

	// MARK: Procs
	typealias CreationProc = (_ id :String, _ documentStorage :MiniDocumentStorage) -> MDSDocument
	typealias ApplyProc<T : MDSDocument> = (_ document :T) -> Void

	// MARK: Equatable implementation
    static func == (lhs: MDSDocument, rhs: MDSDocument) -> Bool { return lhs.id == rhs.id }

	// MARK: Hashable implementation
    func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

	// MARK: Properties
	class	var	documentType :String { return "" }

			var	id :String
			var	miniDocumentStorage: MiniDocumentStorage

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	required init(id :String, miniDocumentStorage :MiniDocumentStorage) {
		// Store
		self.id = id
		self.miniDocumentStorage = miniDocumentStorage
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func bool(for key :String) -> Bool? {
		// Retrieve value
		return self.miniDocumentStorage.value(for: key, documentID: self.id, documentType: type(of: self).documentType)
				as? Bool
	}
	func set(_ value :Bool?, for key :String) {
		// Check if different
		if value != bool(for: key) {
			// Set value
			self.miniDocumentStorage.set(value, for: key, documentID: self.id,
					documentType: type(of: self).documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func date(for key :String) -> Date? {
		// Retrieve value
		return self.miniDocumentStorage.date(
				for:
						self.miniDocumentStorage.value(for: key, documentID: self.id,
								documentType: type(of: self).documentType))
	}
	func set(_ value :Date?, for key :String) {
		// Check if different
		if value != date(for: key) {
			// Set value
			self.miniDocumentStorage.set(self.miniDocumentStorage.value(for: value), for: key, documentID: self.id,
					documentType: type(of: self).documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func double(for key :String) -> Double? {
		// Retrieve value
		return self.miniDocumentStorage.value(for: key, documentID: self.id, documentType: type(of: self).documentType)
				as? Double
	}
	func set(_ value :Double?, for key :String) {
		// Check if different
		if value != double(for: key) {
			// Set value
			self.miniDocumentStorage.set(value, for: key, documentID: self.id,
					documentType: type(of: self).documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func int(for key :String) -> Int? {
		// Retrieve value
		return self.miniDocumentStorage.value(for: key, documentID: self.id, documentType: type(of: self).documentType)
				as? Int
	}
	func set(_ value :Int?, for key :String) {
		// Check if different
		if value != int(for: key) {
			// Set value
			self.miniDocumentStorage.set(value, for: key, documentID: self.id,
					documentType: type(of: self).documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func string(for key :String) -> String? {
		// Retrieve value
		return self.miniDocumentStorage.value(for: key, documentID: self.id, documentType: type(of: self).documentType)
				as? String
	}
	func set(_ value :String?, for key :String) {
		// Check if different
		if value != string(for: key) {
			// Set value
			self.miniDocumentStorage.set(value, for: key, documentID: self.id,
					documentType: type(of: self).documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for key :String) -> T? {
		// Retrieve document ID
		if let documentID = string(for: key) {
			// Return document
			return self.miniDocumentStorage.document(for: documentID)
		} else {
			// No document for this key
			return nil
		}
	}
	func set<T : MDSDocument>(_ document :T?, for key :String) {
		// Check if different
		if document?.id != string(for: key) {
			// Set value
			self.miniDocumentStorage.set(document?.id, for: key, documentID: self.id, documentType: T.documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove() {
		// Remove
		self.miniDocumentStorage.remove(documentID: self.id, documentType: type(of: self).documentType)
	}
}
