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

	// MARK: AttachmentInfo
	public struct AttachmentInfo {

		// MARK: Properties
		public	let	revision :Int
		public	let	info :[String : Any]

		public	var	type :String { info["type"] as! String }

				let	id :String

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(id :String, revision :Int, info :[String : Any]) {
			// Store
			self.revision = revision
			self.info = info

			self.id = id
		}
	}

	// MARK: AttachmentInfoByID
	public typealias AttachmentInfoByID = [/* Attachment ID */ String : AttachmentInfo]

	// MARK: RevisionInfo
	public struct RevisionInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
	}

	// MARK: OverviewInfo
	public struct OverviewInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
		let	creationDate :Date
		let	modificationDate :Date
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
		let	attachmentInfoByID :AttachmentInfoByID
	}

	// MARK: CreateInfo
	public struct CreateInfo {

		// MARK: Properties
		let	documentID :String?
		let	creationDate :Date?
		let	modificationDate :Date?
		let	propertyMap :[String : Any]

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentID :String? = nil, creationDate :Date? = nil, modificationDate :Date? = nil,
				propertyMap :[String : Any] = [:]) {
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
		let	updated :[String : Any]
		let	removed :Set<String>
		let	active :Bool

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentID :String, updated :[String : Any] = [:], removed :Set<String> = Set<String>(),
				active :Bool = true) {
			// Store
			self.documentID = documentID
			self.updated = updated
			self.removed = removed
			self.active = active
		}
	}

	// MARK: Procs
	public	typealias CreateProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument
	public	typealias ChangedProc = (_ document :MDSDocument, _ changeKind :ChangeKind) -> Void
	public	typealias IsIncludedProc = (_ documentType :String, _ document :MDSDocument, _ info :[String : Any]) -> Bool
	public	typealias KeysProc = (_ documentType :String, _ document :MDSDocument, _ info :[String : Any]) -> [String]
	public	typealias ValueProc = (_ documentType :String, _ document :MDSDocument, _ property :String) -> Any

	// MARK: Properties
	class	open	var documentType: String { fatalError("Trying to get documentType of root MDSDocument") }

			public	let	id :String
			public	let	documentStorage: MDSDocumentStorage

			public	var	creationDate :Date { self.documentStorage.documentCreationDate(for: self) }
			public	var	modificationDate :Date { self.documentStorage.documentModificationDate(for: self) }

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
	public func array(for property :String) -> [Any]? {
		// Return value
		return self.documentStorage.documentValue(for: property, of: self) as? [Any]
	}
	public func set<T>(_ value :[T]?, for property :String) {
		// Set value
		self.documentStorage.documentSet(value, for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func bool(for property :String) -> Bool? {
		// Return value
		self.documentStorage.documentValue(for: property, of: self) as? Bool
	}
	@discardableResult
	public func set(_ value :Bool?, for property :String) -> Bool? {
		// Check if different
		let	previousValue = bool(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func data(for property :String) -> Data? { self.documentStorage.documentData(for: property, of: self) }
	@discardableResult
	public func set(_ value :Data?, for property :String) -> Data? {
		// Check if different
		let	previousValue = data(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value?.base64EncodedString(), for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String) -> Date? { self.documentStorage.documentDate(for: property, of: self) }
	@discardableResult
	public func set(_ value :Date?, for property :String) -> Date? {
		// Check if different
		let	previousValue = date(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func double(for property :String) -> Double? {
		// Return value
		return self.documentStorage.documentValue(for: property, of: self) as? Double
	}
	@discardableResult
	public func set(_ value :Double?, for property :String) -> Double? {
		// Check if different
		let	previousValue = double(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
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

				self.documentStorage.documentSet(info, for: property, of: self)
			} else {
				// No value
				self.documentStorage.documentSet(nil, for: property, of: self)
			}
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int(for property :String) -> Int? {
		// Return value
		self.documentStorage.documentValue(for: property, of: self) as? Int
	}
	@discardableResult
	public func set(_ value :Int?, for property :String) -> Int? {
		// Check if different
		let	previousValue = int(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int64(for property :String) -> Int64? {
		// Return value
		self.documentStorage.documentValue(for: property, of: self) as? Int64
	}
	@discardableResult
	public func set(_ value :Int64?, for property :String) -> Int64? {
		// Check if different
		let	previousValue = int64(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func map(for property :String) -> [String : Any]? {
		// Return value
		return self.documentStorage.documentValue(for: property, of: self) as? [String : Any]
	}
	public func set(_ value :[String : Any]?, for property :String) {
		// Set value
		self.documentStorage.documentSet(value, for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(for property :String) -> Set<AnyHashable>? {
		// Get value as array
		if let array = self.documentStorage.documentValue(for: property, of: self) as? [AnyHashable] {
			// Have value
			return Set<AnyHashable>(array)
		} else {
			// No value
			return nil
		}
	}
	public func set<T>(_ value :Set<T>?, for property :String) {
		// Set value
		self.documentStorage.documentSet((value != nil) ? Array(value!) : nil, for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func string(for property :String) -> String? {
		// Return value
		return self.documentStorage.documentValue(for: property, of: self) as? String
	}
	@discardableResult
	public func set(_ value :String?, for property :String) -> String? {
		// Check if different
		let	previousValue = string(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func uint(for property :String) -> UInt? {
		// Return value
		self.documentStorage.documentValue(for: property, of: self) as? UInt
	}
	@discardableResult
	public func set(_ value :UInt?, for property :String) -> UInt? {
		// Check if different
		let	previousValue = uint(for: property)
		if value != previousValue {
			// Set value
			self.documentStorage.documentSet(value, for: property, of: self)
		}
		
		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for property :String) throws -> T? {
		// Retrieve document ID
		guard let documentID = string(for: property) else { return nil }

		return try self.documentStorage.document(for: documentID)
	}
	public func set<T : MDSDocument>(_ document :T?, for property :String) {
		// Check if different
		guard document?.id != string(for: property) else { return }

		// Set value
		self.documentStorage.documentSet(document?.id, for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T : MDSDocument>(for property :String) -> [T]? {
		// Retrieve document ID
		guard let documentIDs = array(for: property) as? [String] else { return nil }

		return try! self.documentStorage.documents(for: documentIDs)
	}
	public func set<T : MDSDocument>(_ documents :[T]?, for property :String) {
		// Set value
		self.documentStorage.documentSet(documents?.map({ $0.id }), for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentMap<T : MDSDocument>(for property :String) -> [String : T]? {
		// Retrieve document IDs map
		guard let storedMap = map(for: property) as? [String : String] else { return nil }

		// Retrieve documents
		let	documents :[T] = try! self.documentStorage.documents(for: Array(storedMap.values))
		guard documents.count == storedMap.count else { return nil }

		// Prepare map from documentID to document
		var	documentMap = [String : T]()
		documents.forEach() { documentMap[$0.id] = $0 }

		return storedMap.mapValues() { documentMap[$0]! }
	}
	public func set<T : MDSDocument>(documentMap :[String : T]?, for property :String) {
		// Set value
		self.documentStorage.documentSet(documentMap?.mapValues({ $0.id }), for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(for property :String) {
		// Update
		self.documentStorage.documentSet(nil, for: property, of: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentInfos(for type :String) -> [AttachmentInfo] {
		// Return filtered attachment infos
		return try! self.documentStorage.documentAttachmentInfoByID(for: self).values.filter({ $0.type == type })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentContent(for attachmentInfo :AttachmentInfo) -> Data {
		// Return attachment content
		return try! self.documentStorage.documentAttachmentContent(for: self, attachmentInfo: attachmentInfo)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentContentAsString(for attachmentInfo :AttachmentInfo) -> String {
		// Get attachment content
		let	data = try! self.documentStorage.documentAttachmentContent(for: self, attachmentInfo: attachmentInfo)

		return String(data: data, encoding: .utf8)!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentContentAsJSON<T>(for attachmentInfo :AttachmentInfo) -> T {
		// Get attachment content
		let	data = try! self.documentStorage.documentAttachmentContent(for: self, attachmentInfo: attachmentInfo)

		return try! JSONSerialization.jsonObject(with: data, options: []) as! T
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentAdd(type :String, info :[String : Any] = [:], content :Data) -> AttachmentInfo {
		// Add attachment
		return try! self.documentStorage.documentAttachmentAdd(to: self, type: type, info: info, content: content)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentAdd(type :String, info :[String : Any] = [:], content :String) -> AttachmentInfo {
		// Add attachment
		try! self.documentStorage.documentAttachmentAdd(to: self, type: type, info: info,
				content: content.data(using: .utf8)!)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentAdd(type :String, info :[String : Any] = [:], content :[String : Any]) -> AttachmentInfo {
		// Add attachment
		try! self.documentStorage.documentAttachmentAdd(to: self, type: type, info: info,
				content: try! JSONSerialization.data(withJSONObject: content, options: []))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentAdd(type :String, info :[String : Any] = [:], content :[[String : Any]]) -> AttachmentInfo {
		// Add attachment
		try! self.documentStorage.documentAttachmentAdd(to: self, type: type, info: info,
				content: try! JSONSerialization.data(withJSONObject: content, options: []))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func update(attachmentInfo :AttachmentInfo, updatedInfo :[String : Any] = [:], updatedContent :Data) {
		// Update attachment
		try! self.documentStorage.documentAttachmentUpdate(for: self, attachmentInfo: attachmentInfo,
				updatedInfo: updatedInfo, updatedContent: updatedContent)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func update(attachmentInfo :AttachmentInfo, updatedInfo :[String : Any] = [:], updatedContent :String) {
		// Update attachment
		try! self.documentStorage.documentAttachmentUpdate(for: self, attachmentInfo: attachmentInfo,
				updatedInfo: updatedInfo, updatedContent: updatedContent.data(using: .utf8)!)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func update(attachmentInfo :AttachmentInfo, updatedInfo :[String : Any] = [:],
			updatedContent :[String : Any]) {
		// Update attachment
		try! self.documentStorage.documentAttachmentUpdate(for: self, attachmentInfo: attachmentInfo,
				updatedInfo: updatedInfo,
				updatedContent: try! JSONSerialization.data(withJSONObject: updatedContent, options: []))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func update(attachmentInfo :AttachmentInfo, updatedInfo :[String : Any] = [:],
			updatedContent :[[String : Any]]) {
		// Update attachment
		try! self.documentStorage.documentAttachmentUpdate(for: self, attachmentInfo: attachmentInfo,
				updatedInfo: updatedInfo,
				updatedContent: try! JSONSerialization.data(withJSONObject: updatedContent, options: []))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(attachmentInfo :AttachmentInfo) {
		// Remove attachment
		try! self.documentStorage.documentAttachmentRemove(from: self, attachmentInfo: attachmentInfo)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove() throws { try self.documentStorage.documentRemove(self) }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentBacking
public protocol MDSDocumentBacking {

	// MARK: Properties
	var	documentID :String { get }
	var	creationDate :Date { get }
	var	propertyMap :[String : Any] { get }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSUpdateInfo
struct MDSUpdateInfo<T> {

	// MARK: Properties
	let	document :MDSDocument
	let	revision :Int
	let	id :T
	let	changedProperties :Set<String>?

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(document :MDSDocument, revision :Int, id :T, changedProperties :Set<String>? = nil) {
		// Store
		self.document = document
		self.revision = revision
		self.id = id
		self.changedProperties = changedProperties
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSValueType {
public enum MDSValueType : String {
	case integer = "integer"
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSValueInfo
public struct MDSValueInfo {

	// MARK: Properties
	let	name :String
	let	type :MDSValueType
}
