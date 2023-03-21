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
// MARK: - MDSDocumentStorageError
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
	func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws
	func associationGet(for name :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, associationItems :[MDSAssociation.Item])
	func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws
	func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws
	func associationGetIntegerValue(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentID :String, cacheName :String, cachedValueName :String) throws -> Int

	func cacheRegister(name :String, documentType :String, relevantProperties :[String], version :Int,
			valueInfos :[(name :String, valueType :MDSValue.Type_, selector :String, proc :MDSDocument.ValueProc)])
			throws

	func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String, isIncludedProcVersion :Int,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc) throws
	func collectionGetDocumentCount(for name :String) throws -> Int
	func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws

	func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) -> [(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)]
	func documentGetCount(for documentType :String) throws -> Int
	func documentIterate(for documentType :String, documentIDs :[String], documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws
	func documentIterate(for documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws

	func documentCreationDate(for document :MDSDocument) -> Date
	func documentModificationDate(for document :MDSDocument) -> Date

	func documentValue(for property :String, of document :MDSDocument) -> Any?
	func documentData(for property :String, of document :MDSDocument) -> Data?
	func documentDate(for property :String, of document :MDSDocument) -> Date?
	func documentSet<T : MDSDocument>(_ value :Any?, for property :String, of document :T)

	func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any], content :Data) throws
			-> MDSDocument.AttachmentInfo
	func documentAttachmentInfoMap(for documentType :String, documentID :String) throws -> MDSDocument.AttachmentInfoMap
	func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws -> Data
	func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int
	func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws

	func documentRemove(_ document :MDSDocument)

	func indexRegister(name :String, documentType :String, relevantProperties :[String], keysInfo :[String : Any],
			keysSelector :String, keysProcVersion :Int, keysProc :@escaping MDSDocument.KeysProc) throws
	func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws

	func info(for keys :[String]) -> [String : String]
	func infoSet(_ info :[String : String])
	func remove(keys :[String])

	func internalGet(for keys :[String]) -> [String : String]
	func internalSet(_ info :[String : String])

	func batch(_ proc :() throws -> MDSBatchResult) rethrows

	func registerDocumentCreateProc<T : MDSDocument>(
			proc :@escaping (_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
	func registerDocumentChangedProc<T : MDSDocument>(
			proc :@escaping (_ document :T, _ changeKind :MDSDocument.ChangeKind) -> Void)

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
				updates: updates.map({ MDSAssociation.Update(action: $0, fromDocumentID: $1.id, toDocumentID: $2.id) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(fromDocumentType :String, toDocumentType :String) throws -> [MDSAssociation.Item] {
		// Get associations
		return try associationGet(
				for: associationName(fromDocumentType: fromDocumentType, toDocumentType: toDocumentType), startIndex: 0,
				count: nil).associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(from document :T, proc :(_ document :U) -> Void)
			throws {
		// Register creation proc
		registerDocumentCreateProc() { U(id: $0, documentStorage: $1) }

		// Iterate association
		try associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				from: document.id, toDocumentType: U.documentType, proc: { proc($0 as! U) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(to document :U, proc :(_ document :T) -> Void)
			throws {
		// Register creation proc
		registerDocumentCreateProc() { T(id: $0, documentStorage: $1) }

		// Iterate association
		try associationIterate(for: associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document.id, fromDocumentType: T.documentType, proc: { proc($0 as! T) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationDocuments<T : MDSDocument, U : MDSDocument>(for name :String? = nil, from document :T) throws
			-> [U] {
		// Register creation proc
		registerDocumentCreateProc() { U(id: $0, documentStorage: $1) }

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
		registerDocumentCreateProc() { T(id: $0, documentStorage: $1) }

		// Iterate
		var	documents = [T]()
		try associationIterate(
				for: name ?? associationName(fromDocumentType: T.documentType, toDocumentType: U.documentType),
				to: document.id, fromDocumentType: T.documentType, proc: { documents.append($0 as! T) })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValue<T : MDSDocument>(from document :T,
			action :MDSAssociation.GetIntegerValueAction, toDocumentType :String, cachedValueName :String) throws ->
					Int {
		// Return value
		return try associationGetIntegerValue(
				for: associationName(fromDocumentType: T.documentType, toDocumentType: toDocumentType), action: action,
				fromDocumentID: document.id, cacheName: T.documentType, cachedValueName: cachedValueName)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValue<T : MDSDocument>(for name :String,
			action :MDSAssociation.GetIntegerValueAction, from document :T, cacheName :String? = nil,
			cachedValueName :String) throws -> Int {
		// Return value
		return try associationGetIntegerValue(for: name, action: action, fromDocumentID: document.id,
				cacheName: cacheName ?? T.documentType, cachedValueName: cachedValueName)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			valueInfos :[(name :String, valueType :MDSValue.Type_, selector :String, proc :MDSDocument.ValueProc)])
			throws {
		// Register cache
		try cacheRegister(name: name, documentType: documentType, relevantProperties: relevantProperties, version: 1,
				valueInfos: valueInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister<T : MDSDocument>(name :String? = nil, relevantProperties :[String]? = nil,
			version :Int = 1,
			valueInfos
					:[(name :String, valueType :MDSValue.Type_, selector :String, proc :(_ document :T, _ name :String)
							-> MDSValue.Value)]) throws {
		// Register creation proc
		registerDocumentCreateProc() { T(id: $0, documentStorage: $1) }

		// Register cache
		try cacheRegister(name: name ?? T.documentType, documentType: T.documentType,
				relevantProperties: relevantProperties ?? valueInfos.map({ $0.name }), version: version,
				valueInfos:
						valueInfos.map(
								{ info in (info.name, info.valueType, info.selector, { info.proc($1 as! T, $2) }) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String],
			isUpToDate :Bool, isIncludedInfo :[String : Any], isIncludedProc :@escaping MDSDocument.IsIncludedProc)
			throws {
		// Register collection
		try collectionRegister(name: name, documentType: documentType, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedInfo: isIncludedInfo, isIncludedSelector: "",
				isIncludedProcVersion: 1, isIncludedProc: isIncludedProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister<T : MDSDocument>(name :String, relevantProperties :[String],
			isUpToDate :Bool = false, isIncludedInfo :[String : Any] = [:], isIncludedSelector :String = "",
			isIncludedProcVersion :Int = 1, isIncludedProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool)
			throws {
		// Register creation proc
		registerDocumentCreateProc() { T(id: $0, documentStorage: $1) }

		// Register collection
		try collectionRegister(name: name, documentType: T.documentType, relevantProperties: relevantProperties,
				isUpToDate: isUpToDate, isIncludedInfo: isIncludedInfo, isIncludedSelector: isIncludedSelector,
				isIncludedProcVersion: isIncludedProcVersion, isIncludedProc: { isIncludedProc($1 as! T, $2) })
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
	public func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) ->
			[MDSDocument.OverviewInfo] {
		// Create documents
		return documentCreate(documentType: documentType, documentCreateInfos: documentCreateInfos,
						proc: { MDSDocument(id: $0, documentStorage: $1) })
				.map({ $0.documentOverviewInfo! })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate<T : MDSDocument>() -> T {
		// Create document
		documentCreate(documentType: T.documentType, documentCreateInfos: [MDSDocument.CreateInfo()],
				proc: { T(id: $0, documentStorage: $1) })[0].document as! T
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>(activeOnly :Bool = true) throws -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate all documents
		try documentIterate(for: T.documentType, sinceRevision: 0, count: nil, activeOnly: activeOnly,
				documentCreateProc: { T(id: $0, documentStorage: $1) }, proc: { documents.append($0 as! T); _ = $1 })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) throws -> T {
		// Retrieve document
		var	document :T?
		try documentIterate(for: T.documentType, documentIDs: [documentID],
				documentCreateProc: { T(id: $0, documentStorage: $1) },
				proc: { document = ($0! as! T); _ = $1 })

		return document!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo] {
		// Collect infos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try documentIterate(for: documentType, documentIDs: documentIDs, documentCreateProc: nil)
				{ documentFullInfos.append($1) }

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo] {
		// Collect infos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try documentIterate(for: documentType, sinceRevision: sinceRevision, count: count, activeOnly: false,
				documentCreateProc: nil) { documentFullInfos.append($1) }

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documents<T :MDSDocument>(for documentIDs :[String]) throws -> [T] {
		// Setup
		var	documents = [T]()

		// Iterate documents for document ids
		try documentIterate(for: T.documentType, documentIDs: documentIDs,
				documentCreateProc: { T(id: $0, documentStorage: $1) }, proc: { documents.append($0 as! T); _ = $1 })

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd<T : MDSDocument>(to document :T, type :String, info :[String : Any],
			content :Data) throws {
		// Setup
		var	infoUse = info
		infoUse["type"] = type

		// Add document attachment
		_ = try documentAttachmentAdd(for: T.documentType, documentID: document.id, info: infoUse, content: content)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for document :MDSDocument) throws -> MDSDocument.AttachmentInfoMap {
		// Get document attachment info map
		return try documentAttachmentInfoMap(for: type(of: document).documentType, documentID: document.id)
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
			keysInfo :[String : Any] = [:], keysProc :@escaping MDSDocument.KeysProc) throws {
		// Register index
		try indexRegister(name: name, documentType: documentType, relevantProperties: relevantProperties,
				keysInfo: keysInfo, keysSelector: "", keysProcVersion: 1, keysProc: keysProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister<T : MDSDocument>(name :String, relevantProperties :[String],
			keysInfo :[String : Any] = [:], keysSelector :String = "", keysProcVersion :Int = 1,
			keysProc :@escaping (_ document :T, _ info :[String : Any]) -> [String]) throws {
		// Register creation proc
		registerDocumentCreateProc() { T(id: $0, documentStorage: $1) }

		// Register index
		try indexRegister(name: name, documentType: T.documentType, relevantProperties: relevantProperties,
				keysInfo: keysInfo, keysSelector: keysSelector, keysProcVersion: keysProcVersion,
				keysProc: { keysProc($1 as! T, $2) })
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

		try indexIterate(name: name, keys: keys) { (key :String, document :T) in documentMap[key] = document }

		return documentMap
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoString(for key :String) -> String? { info(for: [key])[key] }

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func associationName(fromDocumentType :String, toDocumentType :String) -> String {
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
	private	let	documentIsIncludedProcInfosBySelector =
						LockingDictionary<String, (Int, MDSDocument.IsIncludedProc)>()
	private	let	documentKeysProcInfosBySelector =
						LockingDictionary<String, (Int, MDSDocument.KeysProc)>()
	private	let	documentValueProcInfosBySelector =
						LockingDictionary<String, (Int, MDSDocument.ValueProc)>()

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
	public func register(
			isIncludedProcs :[(selector :String, version :Int, isIncludedProc :MDSDocument.IsIncludedProc)]) {
		// Register all
		isIncludedProcs.forEach()
				{ self.documentIsIncludedProcInfosBySelector.set(($0.version, $0.isIncludedProc), for: $0.selector) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register(keysProcs :[(selector :String, version :Int, keysProc :MDSDocument.KeysProc)]) {
		// Register all
		keysProcs.forEach()
				{ self.documentKeysProcInfosBySelector.set(($0.version, $0.keysProc), for: $0.selector) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func register(valueProcs :[(selector :String, version :Int, valueProc :MDSDocument.ValueProc)]) {
		// Register all
		valueProcs.forEach()
				{ self.documentValueProcInfosBySelector.set(($0.version, $0.valueProc), for: $0.selector) }
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
	func documentCreateProc(for documentType :String) -> MDSDocument.CreateProc? {
		// Return proc
		return self.documentCreateProcByDocumentType.value(for: documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentChangedProcs(for documentType :String) -> [MDSDocument.ChangedProc] {
		// Return procs
		return self.documentChangedProcsByDocumentType.values(for: documentType) ?? []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIsIncludedProcInfo(for selector :String) ->
			(version :Int, isIncludedProc :MDSDocument.IsIncludedProc)? {
		// Return proc
		return self.documentIsIncludedProcInfosBySelector.value(for: selector)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentKeysProcInfo(for selector :String) -> (version :Int, keysProc :MDSDocument.KeysProc)? {
		// Return proc
		return self.documentKeysProcInfosBySelector.value(for: selector)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentValueProcInfo(for selector :String) -> (version :Int, valueProc :MDSDocument.ValueProc)? {
		// Return proc
		return self.documentValueProcInfosBySelector.value(for: selector)
	}
}
