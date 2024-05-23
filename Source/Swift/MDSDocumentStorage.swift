//
//  MDSDocumentStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageError
public enum MDSDocumentStorageError : Error {
	case invalidCount(count :Int)
	case invalidDocumentType(documentType :String)
	case invalidStartIndex(startIndex :Int)

	case missingFromIndex(key :String)

	case unknownAssociation(name :String)

	case unknownAttachmentID(attachmentID :String)

	case unknownCache(name :String)
	case unknownCacheValueName(valueName :String)
	case unknownCacheValueSelector(selector :String)

	case unknownCollection(name :String)

	case unknownDocumentID(documentID :String)
	case unknownDocumentType(documentType :String)

	case unknownIndex(name :String)

	case illegalInBatch
}

extension MDSDocumentStorageError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						switch self {
							case .invalidCount(let count): 					return "Invalid count: \(count)"
							case .invalidDocumentType(let documentType):	return "Invalid documentType: \(documentType)"
							case .invalidStartIndex(let startIndex): 		return "Invalid startIndex: \(startIndex)"

							case .missingFromIndex(let key):				return "Missing from index: \(key)"

							case .unknownAssociation(let name):				return "Unknown association: \(name)"

							case .unknownAttachmentID(let attachmentID):	return "Unknown attachmentID: \(attachmentID)"

							case .unknownCache(let name):					return "Unknown cache: \(name)"
							case .unknownCacheValueName(let valueName):		return "Unknown cache valueName: \(valueName)"
							case .unknownCacheValueSelector(let selector):	return "Invalid value selector: \(selector)"

							case .unknownCollection(let name):				return "Unknown collection: \(name)"

							case .unknownDocumentID(let documentID):		return "Unknown documentID: \(documentID)"
							case .unknownDocumentType(let documentType):	return "Unknown documentType: \(documentType)"

							case .unknownIndex(let name):					return "Unknown index: \(name)"

							case .illegalInBatch:							return "Illegal in batch"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage protocol
public protocol MDSDocumentStorage {

	// MARK: Properties
	var	id :String { get }

	// MARK: Instance methods
	func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws
	func associationGet(for name :String) throws -> [MDSAssociation.Item]
	func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws
	func associationIterate(for name :String, fromDocumentType :String, to toDocumentID :String,
			proc :(_ document :MDSDocument) -> Void) throws
	func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) throws -> [String : Int64]
	func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws

	func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			cacheValueInfos :[(valueInfo :MDSValueInfo, selector :String)]) throws

	func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc) throws
	func collectionGetDocumentCount(for name :String) throws -> Int
	func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws

	func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) throws ->
			[(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)]
	func documentGetCount(for documentType :String) throws -> Int
	func documentIterate(for documentType :String, documentIDs :[String], documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws
	func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws

	func documentCreationDate(for document :MDSDocument) -> Date
	func documentModificationDate(for document :MDSDocument) -> Date

	func documentValue(for property :String, of document :MDSDocument) -> Any?
	func documentData(for property :String, of document :MDSDocument) -> Data?
	func documentDate(for property :String, of document :MDSDocument) -> Date?
	func documentSet<T : MDSDocument>(_ value :Any?, for property :String, of document :T)

	func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any], content :Data) throws
			-> MDSDocument.AttachmentInfo
	func documentAttachmentInfoByID(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoByID
	func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws -> Data
	func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int?
	func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws

	func documentRemove(_ document :MDSDocument) throws

	func indexRegister(name :String, documentType :String, relevantProperties :[String], keysInfo :[String : Any],
			keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws
	func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws

	func infoGet(for keys :[String]) throws -> [String : String]
	func infoSet(_ info :[String : String]) throws
	func infoRemove(keys :[String]) throws

	func internalGet(for keys :[String]) -> [String : String]
	func internalSet(_ info :[String : String]) throws

	func batch(_ proc :() throws -> MDSBatchResult) rethrows

	func register<T : MDSDocument>(
			documentCreateProc :@escaping (_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
	func register<T : MDSDocument>(
			documentChangedProc :@escaping (_ document :T, _ changeKind :MDSDocument.ChangeKind) -> Void)

	func ephemeralValue<T>(for key :String) -> T?
	func store<T>(ephemeralValue :T?, for key :String)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorage extension
extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(fromDocumentType :String, toDocumentType :String) throws {
		// Register association
		try associationRegister(
				named: associationName(fromDocumentType: fromDocumentType, toDocumentType: toDocumentType),
				fromDocumentType :fromDocumentType, toDocumentType :toDocumentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate<T : MDSDocument, U : MDSDocument>(
			updates :[(action :MDSAssociation.Update.Action, fromDocument :T, toDocument :U)]) throws {
		// Update association
		try associationUpdate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				updates: updates.map({ MDSAssociation.Update($0, fromDocumentID: $1.id, toDocumentID: $2.id) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(from document :T, proc :(_ document :U) -> Void)
			throws {
		// Register creation proc
		register(documentCreateProc: { U(id: $0, documentStorage: $1) })

		// Iterate association
		try associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document.id, toDocumentType: U.documentType, proc: { proc($0 as! U) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(to document :U, proc :(_ document :T) -> Void)
			throws {
		// Register creation proc
		register(documentCreateProc: { T(id: $0, documentStorage: $1) })

		// Iterate association
		try associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				fromDocumentType: T.documentType, to: document.id, proc: { proc($0 as! T) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationDocuments<T : MDSDocument, U : MDSDocument>(for name :String? = nil, from document :T) throws
			-> [U] {
		// Register creation proc
		register(documentCreateProc: { U(id: $0, documentStorage: $1) })

		// Iterate
		var	documents = [U]()
		try associationIterate(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document.id, toDocumentType: U.documentType, proc: { documents.append($0 as! U) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationDocuments<T : MDSDocument, U : MDSDocument>(for name :String? = nil, to document :U) throws
			-> [T] {
		// Register creation proc
		register(documentCreateProc: { T(id: $0, documentStorage: $1) })

		// Iterate
		var	documents = [T]()
		try associationIterate(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				fromDocumentType: T.documentType, to: document.id, proc: { documents.append($0 as! T) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(documentType :String, relevantProperties :[String]? = nil,
			cacheValueInfos :[(valueInfo :MDSValueInfo, selector :String)]) throws {
		// Register cache
		try cacheRegister(name: documentType, documentType: documentType,
				relevantProperties: relevantProperties ?? cacheValueInfos.map({ $0.valueInfo.name }),
				cacheValueInfos: cacheValueInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String],
			isUpToDate :Bool = false, isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Register collection
		try collectionRegister(name: name, documentType: documentType, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedInfo: [:], isIncludedSelector: isIncludedSelector,
				documentIsIncludedProc: documentIsIncludedProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister<T : MDSDocument>(name :String, relevantProperties :[String],
			isUpToDate :Bool = false, isIncludedInfo :[String : Any] = [:], isIncludedSelector :String,
			isIncludedProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) throws {
		// Register creation proc
		register(documentCreateProc: { T(id: $0, documentStorage: $1) })

		// Register collection
		try collectionRegister(name: name, documentType: T.documentType, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedInfo: isIncludedInfo, isIncludedSelector: isIncludedSelector,
				documentIsIncludedProc: { isIncludedProc($1 as! T, $2) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) throws {
		// Iterate collection
		try collectionIterate(name: name, documentType: T.documentType, proc: { proc($0 as! T) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionDocuments<T : MDSDocument>(for name :String) throws -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate
		try collectionIterate(name: name) { (t :T) in documents.append(t) }

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) throws ->
			[MDSDocument.OverviewInfo] {
		// Create documents
		return try documentCreate(documentType: documentType, documentCreateInfos: documentCreateInfos,
						proc: { MDSDocument(id: $0, documentStorage: $1) })
				.map({ $0.documentOverviewInfo! })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate<T : MDSDocument>(proc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T) throws
			-> T {
		// Create document
		try documentCreate(documentType: T.documentType, documentCreateInfos: [MDSDocument.CreateInfo()],
				proc: proc)[0].document as! T
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate<T : MDSDocument>() throws -> T {
		// Create document
		try documentCreate(documentType: T.documentType, documentCreateInfos: [MDSDocument.CreateInfo()],
				proc: { T(id: $0, documentStorage: $1) })[0].document as! T
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>(activeOnly :Bool = true) throws -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate all documents
		try documentIterate(for: T.documentType, activeOnly: activeOnly,
				documentCreateProc: { T(id: $0, documentStorage: $1) }, proc: { documents.append($0 as! T) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) throws -> T {
		// Retrieve document
		var	document :T?
		try documentIterate(for: T.documentType, documentIDs: [documentID],
				documentCreateProc: { T(id: $0, documentStorage: $1) }, proc: { document = ($0 as! T) })

		return document!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>(for documentIDs :[String]) throws -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate documents for document ids
		try documentIterate(for: T.documentType, documentIDs: documentIDs,
				documentCreateProc: { T(id: $0, documentStorage: $1) }, proc: { documents.append($0 as! T) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd<T : MDSDocument>(to document :T, type :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
		// Setup
		var	infoUse = info
		infoUse["type"] = type

		return try documentAttachmentAdd(for: T.documentType, documentID: document.id, info: infoUse, content: content)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoByID(for document :MDSDocument) throws -> MDSDocument.AttachmentInfoByID {
		// Get document attachment info map
		return try documentAttachmentInfoByID(for: type(of: document).documentType, documentID: document.id)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo)
			throws -> Data {
		// Return document attachment content
		return try documentAttachmentContent(for: T.documentType, documentID: document.id,
				attachmentID: attachmentInfo.id)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo,
			updatedInfo :[String : Any], updatedContent :Data) throws {
		// Setup
		var	updatedInfoUse = updatedInfo
		updatedInfoUse["type"] = attachmentInfo.type

		// Update document attachment
		_ = try documentAttachmentUpdate(for: T.documentType, documentID: document.id, attachmentID: attachmentInfo.id,
				updatedInfo: updatedInfoUse, updatedContent: updatedContent)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove<T : MDSDocument>(from document :T, attachmentInfo :MDSDocument.AttachmentInfo)
			throws {
		// Remove document attachment
		try documentAttachmentRemove(for: T.documentType, documentID: document.id, attachmentID: attachmentInfo.id)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String],
			keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
		// Register index
		try indexRegister(name: name, documentType: documentType, relevantProperties: relevantProperties,
				keysInfo: [:], keysSelector: keysSelector, keysProc: keysProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister<T : MDSDocument>(name :String, relevantProperties :[String],
			keysInfo :[String : Any] = [:], keysSelector :String,
			keysProc :@escaping (_ document :T, _ info :[String : Any]) -> [String]) throws {
		// Register creation proc
		register(documentCreateProc: { T(id: $0, documentStorage: $1) })

		// Register index
		try indexRegister(name: name, documentType: T.documentType, relevantProperties: relevantProperties,
				keysInfo: keysInfo, keysSelector: keysSelector, keysProc: { keysProc($1 as! T, $2) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) throws {
		// Iterate index
		try indexIterate(name: name, documentType: T.documentType, keys: keys, proc: { proc($0, $1 as! T) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexDocumentMap<T : MDSDocument>(for name :String, keys :[String]) throws -> [String : T] {
		// Setup
		var	documentMap = [String : T]()

		// Iterate index
		try indexIterate(name: name, keys: keys) { (key :String, document :T) in documentMap[key] = document }

		return documentMap
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoString(for key :String) throws -> String? { try infoGet(for: [key])[key] }

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	func associationName(fromDocumentType :String, toDocumentType :String) -> String {
		// Return
		return "\(fromDocumentType)To\(toDocumentType.capitalizingFirstLetter)"
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageCore
open class MDSDocumentStorageCore {

	// MARK: Properties
	public	let	id :String = UUID().uuidString

	private	let	documentCreateProcByDocumentType = LockingDictionary<String, MDSDocument.CreateProc>()
	private	let	documentChangedProcsByDocumentType = LockingArrayDictionary<String, MDSDocument.ChangedProc>()
	private	let	documentIsIncludedProcsBySelector = LockingDictionary<String, MDSDocument.IsIncludedProc>()
	private	let	documentKeysProcsBySelector = LockingDictionary<String, MDSDocument.KeysProc>()
	private	let	documentValueProcsBySelector = LockingDictionary<String, MDSDocument.ValueProc>()

	private	var	ephemeralValues :[/* Key */ String : Any]?

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func register<T : MDSDocument>(
			documentCreateProc :@escaping (_ id :String, _ documentStorage :MDSDocumentStorage) -> T) {
		// Add
		self.documentCreateProcByDocumentType.set(documentCreateProc, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register<T : MDSDocument>(
			documentChangedProc :@escaping (_ document :T, _ changeKind :MDSDocument.ChangeKind) -> Void) {
		//  Add
		self.documentChangedProcsByDocumentType.append({ documentChangedProc($0 as! T, $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register(isIncludedProcs :[(selector :String, isIncludedProc :MDSDocument.IsIncludedProc)]) {
		// Register all
		isIncludedProcs.forEach() { self.documentIsIncludedProcsBySelector.set($0.isIncludedProc, for: $0.selector) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register(keysProcs :[(selector :String, keysProc :MDSDocument.KeysProc)]) {
		// Register all
		keysProcs.forEach() { self.documentKeysProcsBySelector.set($0.keysProc, for: $0.selector) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register(valueProcs :[(selector :String, valueProc :MDSDocument.ValueProc)]) {
		// Register all
		valueProcs.forEach() { self.documentValueProcsBySelector.set($0.valueProc, for: $0.selector) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func ephemeralValue<T>(for key :String) -> T? { self.ephemeralValues?[key] as? T }

	//------------------------------------------------------------------------------------------------------------------
	public func store<T>(ephemeralValue value :T?, for key :String) {
		// Store
		if (self.ephemeralValues == nil) && (value != nil) {
			// First one
			self.ephemeralValues = [key : value!]
		} else {
			// Update
			self.ephemeralValues?[key] = value

			// Check for empty
			if self.ephemeralValues?.isEmpty ?? false {
				// No more values
				self.ephemeralValues = nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCreateProc(for documentType :String) -> MDSDocument.CreateProc {
		// Return proc
		return self.documentCreateProcByDocumentType.value(for: documentType) ??
				{ MDSDocument(id: $0, documentStorage: $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentChangedProcs(for documentType :String) -> [MDSDocument.ChangedProc] {
		// Return procs
		return self.documentChangedProcsByDocumentType.values(for: documentType) ?? []
	}

	//------------------------------------------------------------------------------------------------------------------
	func noteDocumentChanged(document :MDSDocument, changeKind :MDSDocument.ChangeKind) {
		// Call procs
		self.documentChangedProcs(for: type(of: document).documentType).forEach() { $0(document, changeKind) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIsIncludedProc(for selector :String) -> MDSDocument.IsIncludedProc? {
		// Return proc
		return self.documentIsIncludedProcsBySelector.value(for: selector)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentKeysProc(for selector :String) -> MDSDocument.KeysProc? {
		// Return proc
		return self.documentKeysProcsBySelector.value(for: selector)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentValueProc(for selector :String) -> MDSDocument.ValueProc? {
		// Return proc
		return self.documentValueProcsBySelector.value(for: selector)
	}
}
