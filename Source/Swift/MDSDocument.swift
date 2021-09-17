//
//  MDSDocument.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument
open class MDSDocument : Hashable {

	// MARK: ChangeKind
	public enum ChangeKind {
		case created
		case updated
		case removed
	}

	// MARK: BackingInfo
	struct BackingInfo<T> {

		// MARK: Properties
		let	documentID :String
		let	documentBacking :T
	}

	// MARK: RevisionInfo
	public struct RevisionInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
	}

	// MARK: FullInfo
	public struct FullInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
		let	active :Bool
		let	creationDate :Date
		let	modificationDate :Date
		let	propertyMap :[String : Any]
	}

	// MARK: CreateInfo
	struct CreateInfo {

		// MARK: Properties
		let	documentID :String
		let	creationDate :Date?
		let	modificationDate :Date?
		let	propertyMap :[String : Any]

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
				propertyMap :[String : Any]) {
			// Store
			self.documentID = documentID
			self.creationDate = creationDate
			self.modificationDate = modificationDate
			self.propertyMap = propertyMap
		}
	}

	// MARK: UpdateInfo
	struct UpdateInfo {

		// MARK: Properties
		let	documentID :String
		let	active :Bool
		let	updated :[String : Any]
		let	removed :Set<String>

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentID :String, active :Bool = true, updated :[String : Any] = [:],
				removed :Set<String> = Set<String>()) {
			// Store
			self.documentID = documentID
			self.active = active
			self.updated = updated
			self.removed = removed
		}
	}

	// MARK: Procs
	public	typealias ChangedProc = (_ document :MDSDocument, _ changeKind :ChangeKind) -> Void

			typealias PropertyMap = [/* Property */ String : /* Value */ Any]

			typealias CreationProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument

	// MARK: Properties
	class	open	var documentType: String { fatalError("Trying to get documentType of root MDSDocument") }

			public	let	id :String
			public	let	documentStorage: MDSDocumentStorage

			public	var	creationDate :Date { self.documentStorage.creationDate(for: self) }
			public	var	modificationDate :Date { self.documentStorage.modificationDate(for: self) }

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	static public func ==(lhs :MDSDocument, rhs :MDSDocument) -> Bool { lhs.id == rhs.id }

	// MARK: Hashable implementation
	//------------------------------------------------------------------------------------------------------------------
	public func hash(into hasher :inout Hasher) { hasher.combine(self.id) }

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public required init(id :String, documentStorage :MDSDocumentStorage) {
		// Store
		self.id = id
		self.documentStorage = documentStorage
	}


	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func array(for property :String) -> [Any]? { self.documentStorage.value(for: property, in: self) as? [Any] }
	public func set<T>(_ value :[T]?, for property :String) { self.documentStorage.set(value, for: property, in: self) }

	//------------------------------------------------------------------------------------------------------------------
	public func bool(for property :String) -> Bool? { self.documentStorage.value(for: property, in: self) as? Bool }
	@discardableResult
	public func set(_ value :Bool?, for property :String) -> Bool? {
		// Check if different
		let	previousValue = bool(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func data(for property :String) -> Data? { self.documentStorage.data(for: property, in: self) }
	@discardableResult
	public func set(_ value :Data?, for property :String) -> Data? {
		// Check if different
		let	previousValue = data(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value?.base64EncodedString(), for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String) -> Date? { self.documentStorage.date(for: property, in: self) }
	@discardableResult
	public func set(_ value :Date?, for property :String) -> Date? {
		// Check if different
		let	previousValue = date(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func double(for property :String) -> Double? {
		// Return value
		return self.documentStorage.value(for: property, in: self) as? Double
	}
	@discardableResult
	public func set(_ value :Double?, for property :String) -> Double? {
		// Check if different
		let	previousValue = double(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	// 9/8/2020 - Stevo removing "NSUserInfo" from the round-trip as it can contain nested NSErrors which are not
	//	currently converted to dictionaries, which trigger fatal errors when converted to JSON.
	//	Can re-enable this in the future if required.
	public func nsError(for property :String) -> NSError? {
		// Retrieve info
		guard let info = map(for: property), let domain = info["NSDomain"] as? String, let code = info["NSCode"] as? Int
				else { return nil }

		var	userInfo = [String : Any]()
		userInfo[NSLocalizedDescriptionKey] = info[NSLocalizedDescriptionKey]

		return NSError(domain: domain, code: code, userInfo: userInfo)
	}
	@discardableResult
	public func set(_ value :NSError?, for property :String) -> NSError? {
		// Check if different
		let	previousValue = nsError(for: property)
		if value != previousValue {
			// Set value
			if value != nil {
				// Have value
				var	info :[String : Any] = [
											"NSDomain": value!.domain,
											"NSCode": value!.code,
										   ]
				info[NSLocalizedDescriptionKey] = value!.userInfo[NSLocalizedDescriptionKey]

				self.documentStorage.set(info, for: property, in: self)
			} else {
				// No value
				self.documentStorage.set(nil, for: property, in: self)
			}
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int(for property :String) -> Int? { self.documentStorage.value(for: property, in: self) as? Int }
	@discardableResult
	public func set(_ value :Int?, for property :String) -> Int? {
		// Check if different
		let	previousValue = int(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int64(for property :String) -> Int64? { self.documentStorage.value(for: property, in: self) as? Int64 }
	@discardableResult
	public func set(_ value :Int64?, for property :String) -> Int64? {
		// Check if different
		let	previousValue = int64(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func map(for property :String) -> [String : Any]? {
		// Return value
		return self.documentStorage.value(for: property, in: self) as? [String : Any]
	}
	public func set(_ value :[String : Any]?, for property :String) {
		// Set value
		self.documentStorage.set(value, for: property, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(for property :String) -> Set<AnyHashable>? {
		// Get value as array
		if let array = self.documentStorage.value(for: property, in: self) as? [AnyHashable] {
			// Have value
			return Set<AnyHashable>(array)
		} else {
			// No value
			return nil
		}
	}
	public func set<T>(_ value :Set<T>?, for property :String) {
		// Set value
		self.documentStorage.set((value != nil) ? Array(value!) : nil, for: property, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func string(for property :String) -> String? {
		// Return value
		return self.documentStorage.value(for: property, in: self) as? String
	}
	@discardableResult
	public func set(_ value :String?, for property :String) -> String? {
		// Check if different
		let	previousValue = string(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func uint(for property :String) -> UInt? { self.documentStorage.value(for: property, in: self) as? UInt }
	@discardableResult
	public func set(_ value :UInt?, for property :String) -> UInt? {
		// Check if different
		let	previousValue = uint(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.set(value, for: property, in: self)
		}
		
		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for property :String) -> T? {
		// Retrieve document ID
		guard let documentID = string(for: property) else { return nil }

		return self.documentStorage.document(for: documentID)
	}
	public func set<T : MDSDocument>(_ document :T?, for property :String) {
		// Check if different
		guard document?.id != string(for: property) else { return }

		// Set value
		self.documentStorage.set(document?.id, for: property, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T : MDSDocument>(for property :String) -> [T]? {
		// Retrieve document ID
		guard let documentIDs = array(for: property) as? [String] else { return nil }

		return self.documentStorage.documents(for: documentIDs)
	}
	public func set<T : MDSDocument>(_ documents :[T]?, for property :String) {
		// Set value
		self.documentStorage.set(documents?.map({ $0.id }), for: property, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentMap<T : MDSDocument>(for property :String) -> [String : T]? {
		// Retrieve document IDs map
		guard let storedMap = map(for: property) as? [String : String] else { return nil }

		// Retrieve documents
		let	documents :[T] = self.documentStorage.documents(for: Array(storedMap.values))
		guard documents.count == storedMap.count else { return nil }

		// Prepare map from documentID to document
		var	documentMap = [String : T]()
		documents.forEach() { documentMap[$0.id] = $0 }

		return storedMap.mapValues() { documentMap[$0]! }
	}
	public func set<T : MDSDocument>(documentMap :[String : T]?, for property :String) {
		// Set value
		self.documentStorage.set(documentMap?.mapValues({ $0.id }), for: property, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(for property :String) { self.documentStorage.set(nil, for: property, in: self) }
	
	//------------------------------------------------------------------------------------------------------------------
	public func remove() { self.documentStorage.remove(self) }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSUpdateInfo
struct MDSUpdateInfo<T> {

	// MARK: Properties
	let	document :MDSDocument
	let	revision :Int
	let	value :T
	let	changedProperties :Set<String>?
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBringUpToDateInfo
struct MDSBringUpToDateInfo<T> {

	// MARK: Properties
	let	document :MDSDocument
	let	revision :Int
	let	value :T
}
