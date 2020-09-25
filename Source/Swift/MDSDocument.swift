//
//  MDSDocument.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentChangeKind
public enum MDSDocumentChangeKind {
	case created
	case updated
	case removed
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument
public protocol MDSDocument {

	// MARK: Types
	typealias PropertyMap = [/* Property */ String : /* Value */ Any]

	typealias CreationProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument
	typealias ChangedProc = (_ document :MDSDocument, _ kind :MDSDocumentChangeKind) -> Void

	// MARK: Properties
	static	var	documentType :String { get }

			var	id :String { get }
			var	documentStorage: MDSDocumentStorage { get }

	// MARK: Lifecycle methods
	init(id :String, documentStorage :MDSDocumentStorage)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument extension
extension MDSDocument {

	// MARK: Properties
	public	var	creationDate :Date { self.documentStorage.creationDate(for: self) }
	public	var	modificationDate :Date { self.documentStorage.modificationDate(for: self) }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func array(for key :String) -> [Any]? { self.documentStorage.value(for: key, in: self) as? [Any] }
	public func set<T>(_ value :[T]?, for key :String) { self.documentStorage.set(value, for: key, in: self) }

	//------------------------------------------------------------------------------------------------------------------
	public func bool(for key :String) -> Bool? { self.documentStorage.value(for: key, in: self) as? Bool }
	@discardableResult public func set(_ value :Bool?, for key :String) -> Bool? {
		// Check if different
		let	previousValue = bool(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func data(for key :String) -> Data? {
		// Retrieve Base64-encoded string
		guard let string = self.documentStorage.value(for: key, in: self) as? String else { return nil }

		return Data(base64Encoded: string)
	}
	@discardableResult public func set(_ value :Data?, for key :String) -> Data? {
		// Check if different
		let	previousValue = data(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value?.base64EncodedString(), for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for key :String) -> Date? { self.documentStorage.date(for: key, in: self) }
	@discardableResult public func set(_ value :Date?, for key :String) -> Date? {
		// Check if different
		let	previousValue = date(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func double(for key :String) -> Double? { self.documentStorage.value(for: key, in: self) as? Double }
	@discardableResult public func set(_ value :Double?, for key :String) -> Double? {
		// Check if different
		let	previousValue = double(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	// 9/8/2020 - Stevo removing "NSUserInfo" from the round-trip as it can contain nested NSErrors which are not
	//	currently converted to dictionaries, which trigger fatal errors when converted to JSON.
	//	Can re-enable this in the future if required.
	public func nsError(for key :String) -> NSError? {
		// Retrieve info
		guard let info = map(for: key), let domain = info["NSDomain"] as? String, let code = info["NSCode"] as? Int else
				{ return nil }

		var	userInfo = [String : Any]()
		userInfo[NSLocalizedDescriptionKey] = info[NSLocalizedDescriptionKey]

		return NSError(domain: domain, code: code, userInfo: userInfo)
	}
	@discardableResult public func set(_ value :NSError?, for key :String) -> NSError? {
		// Check if different
		let	previousValue = nsError(for: key)
		guard value != previousValue else { return value }

		// Set value
		if value != nil {
			// Have value
			var	info :[String : Any] = [
										"NSDomain": value!.domain,
										"NSCode": value!.code,
									   ]
			info[NSLocalizedDescriptionKey] = value!.userInfo[NSLocalizedDescriptionKey]

			self.documentStorage.set(info, for: key, in: self)
		} else {
			// No value
			self.documentStorage.set(nil, for: key, in: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int(for key :String) -> Int? { self.documentStorage.value(for: key, in: self) as? Int }
	@discardableResult public func set(_ value :Int?, for key :String) -> Int? {
		// Check if different
		let	previousValue = int(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int64(for key :String) -> Int64? { self.documentStorage.value(for: key, in: self) as? Int64 }
	@discardableResult public func set(_ value :Int64?, for key :String) -> Int64? {
		// Check if different
		let	previousValue = int64(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func map(for key :String) -> [String : Any]? {
		// Return value
		return self.documentStorage.value(for: key, in: self) as? [String : Any]
	}
	public func set(_ value :[String : Any]?, for key :String) {
		// Set value
		self.documentStorage.set(value, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(for key :String) -> Set<AnyHashable>? {
		// Query value as array
		if let array = self.documentStorage.value(for: key, in: self) as? [AnyHashable] {
			// Have value
			return Set<AnyHashable>(array)
		} else {
			// No value
			return nil
		}
	}
	public func set<T>(_ value :Set<T>?, for key :String) {
		// Set value
		self.documentStorage.set((value != nil) ? Array(value!) : nil, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func string(for key :String) -> String? { self.documentStorage.value(for: key, in: self) as? String }
	@discardableResult public func set(_ value :String?, for key :String) -> String? {
		// Check if different
		let	previousValue = string(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func uint(for key :String) -> UInt? { self.documentStorage.value(for: key, in: self) as? UInt }
	@discardableResult public func set(_ value :UInt?, for key :String) -> UInt? {
		// Check if different
		let	previousValue = uint(for: key)
		guard value != previousValue else { return value }

		// Set value
		self.documentStorage.set(value, for: key, in: self)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(with documentID :String) -> T? {
		// Retrieve document
		return self.documentStorage.document(for: documentID)
	}
	public func document<T : MDSDocument>(for key :String) -> T? {
		// Retrieve document ID
		guard let documentID = string(for: key) else { return nil }

		return self.documentStorage.document(for: documentID)
	}
	public func set<T : MDSDocument>(_ document :T?, for key :String) {
		// Check if different
		guard document?.id != string(for: key) else { return }

		// Set value
		self.documentStorage.set(document?.id, for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T : MDSDocument>(for key :String) -> [T]? {
		// Retrieve document ID
		guard let documentIDs = array(for: key) as? [String] else { return nil }

		return self.documentStorage.documents(for: documentIDs)
	}
	public func set<T : MDSDocument>(_ documents :[T]?, for key :String) {
		// Set value
		self.documentStorage.set(documents?.map({ $0.id }), for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentMap<T : MDSDocument>(for key :String) -> [String : T]? {
		// Retrieve document IDs map
		guard let storedMap = map(for: key) as? [String : String] else { return nil }

		let	documents :[T] = self.documentStorage.documents(for: Array(storedMap.values))
		guard documents.count == storedMap.count else { return nil }

		// Prepare map from document ID to document
		var	documentMap = [String : T]()
		documents.forEach() { documentMap[$0.id] = $0 }

		return storedMap.mapValues() { documentMap[$0]! }
	}
	public func set<T : MDSDocument>(documentMap :[String : T]?, for key :String) {
		// Set value
		self.documentStorage.set(documentMap?.mapValues({ $0.id }), for: key, in: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(for key :String) { self.documentStorage.set(nil, for: key, in: self) }
	
	//------------------------------------------------------------------------------------------------------------------
	public func remove() { self.documentStorage.remove(self) }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentInstance
public class MDSDocumentInstance : Hashable, MDSDocument {

	// MARK: Properties
	class	public	var documentType: String { "" }

			public	let	id :String
			public	let	documentStorage: MDSDocumentStorage

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	required public init(id :String, documentStorage :MDSDocumentStorage) {
		// Store
		self.id = id
		self.documentStorage = documentStorage
	}

	// MARK: Equatable implementation
	static	public	func == (lhs: MDSDocumentInstance, rhs: MDSDocumentInstance) -> Bool { lhs.id == rhs.id }

	// MARK: Hashable implementation
	public func hash(into hasher: inout Hasher) { hasher.combine(self.id) }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentBackingInfo
public struct MDSDocumentBackingInfo<T> {

	// MARK: Properties
	let	documentID :String
	let	documentBacking :T
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentRevisionInfo
struct MDSDocumentRevisionInfo {

	// MARK: Properties
	let	documentID :String
	let	revision :Int
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentFullInfo
struct MDSDocumentFullInfo {

	// MARK: Properties
	let	documentID :String
	let	revision :Int
	let	creationDate :Date
	let	modificationDate :Date
	let	propertyMap :MDSDocument.PropertyMap
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentCreateInfo
struct MDSDocumentCreateInfo {

	// MARK: Properties
	let	documentID :String?
	let	creationDate :Date?
	let	modificationDate :Date?
	let	propertyMap :MDSDocument.PropertyMap
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentUpdateInfo
struct MDSDocumentUpdateInfo {

	// MARK: Properties
	let	documentID :String
	let	updated :MDSDocument.PropertyMap
	let	removed :[String]
	let	active :Bool
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSUpdateInfo
struct MDSUpdateInfo<T> {

	// MARK: Properties
	let	document :MDSDocument
	let	revision :Int
	let	value :T
	let	changedProperties :[String]?
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBringUpToDateInfo
struct MDSBringUpToDateInfo<T> {

	// MARK: Properties
	let	document :MDSDocument
	let	revision :Int
	let	value :T
}
