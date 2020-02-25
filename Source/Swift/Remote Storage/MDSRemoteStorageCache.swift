//
//  MDSRemoteStorageCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 1/14/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSRemoteStorageCache
public class MDSRemoteStorageCache {

	// MARK: Types
	public struct DocumentReference {

		// MARK: Properties
		let	id :String
		let	revision :Int
	}

	public struct DocumentInfo {

		// MARK: Properties
		let id :String
		let	revision :Int
		let	active :Bool
		let	creationDate :Date
		let	modificationDate :Date
		let	propertyMap :[String : Any]
	}

	// MARK: Properties
	private	var	sqliteDatabase :SQLiteDatabase!
	private	var	infoTable :SQLiteTable!
	private	var	sqliteTables = [/* document type */ String : SQLiteTable]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(storageFolderURL :URL, uniqueID :String) {
		// Create if needed
		if !FileManager.default.fileExists(atPath: storageFolderURL.path) {
			// Catch errors
			do {
				// Create folder
				try FileManager.default.createDirectory(at: storageFolderURL, withIntermediateDirectories: true,
						attributes: nil)
			} catch {
				// Error
				LILogc("MDSRemoteStorageCache unable to create folder at \(storageFolderURL.path).")

				return
			}
		}

		// Catch errors
		do {
			// Setup SQLite database
			self.sqliteDatabase = try SQLiteDatabase(url: storageFolderURL.appendingPathComponent(uniqueID))

			self.infoTable =
					self.sqliteDatabase.table(name: "Info", options: [.withoutRowID],
							tableColumns: [
											SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull]),
											SQLiteTableColumn("value", .text, [.notNull]),
										  ])
			self.infoTable.create()

			var	version :Int?
			try! self.infoTable.select(tableColumns: [self.infoTable.valueTableColumn],
					where: SQLiteWhere(tableColumn: self.infoTable.keyTableColumn, value: "version")) {
				// Process values
				version = Int($0.text(for: self.infoTable.valueTableColumn)!)!
			}
			if version == nil {
				// Initialize version
				version = 1
				_ = self.infoTable.insertRow([
												(self.infoTable.keyTableColumn, "version"),
												(self.infoTable.valueTableColumn, version!),
											 ])
			}
		} catch {
			// Error
			LILogc("MDSRemoteStorageCache unable to initialize database.")

			return
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func documentInfos(for documentType :String, with references :[DocumentReference]) ->
			(documentInfos :[DocumentInfo], documentReferencesNotResolved :[DocumentReference]) {
		// Setup
		let	sqliteTable = self.sqliteTable(for: documentType)
		let	referenceMap = Dictionary(uniqueKeysWithValues: references.lazy.map({ ($0.id, $0.revision) }))

		let	idTableColumn = sqliteTable.idTableColumn
		let	revisionTableColumn = sqliteTable.revisionTableColumn
		let	activeTableColumn = sqliteTable.activeTableColumn
		let	creationDateTableColumn = sqliteTable.creationDateTableColumn
		let	modificationDateTableColumn = sqliteTable.modificationDateTableColumn
		let	jsonTableColumn = sqliteTable.jsonTableColumn

		var	documentIDs = Set<String>(referenceMap.keys)

		// Iterate records in database
		var	documentInfos = [DocumentInfo]()
		var	documentReferencesNotResolved = [DocumentReference]()
		try! sqliteTable.select(where: SQLiteWhere(tableColumn: sqliteTable.idTableColumn,
				values: Array(documentIDs))) {
					// Retrieve info for this record
					let	id = $0.text(for: idTableColumn)!
					let	revision :Int = $0.integer(for: revisionTableColumn)!
					if revision == referenceMap[id] {
						// Revision matches
						let	active :Int = $0.integer(for: activeTableColumn)!
						let	creationDate = Date(timeIntervalSince1970: $0.real(for: creationDateTableColumn)!)
						let	modificationDate = Date(timeIntervalSince1970: $0.real(for: modificationDateTableColumn)!)
						let	propertyMap =
									try! JSONSerialization.jsonObject(with: $0.blob(for: jsonTableColumn)!, options: [])
											as! [String : Any]

						documentInfos.append(
								DocumentInfo(id: id, revision: revision, active: active == 1,
										creationDate: creationDate, modificationDate: modificationDate,
										propertyMap: propertyMap))
					} else {
						// Revision does not match
						documentReferencesNotResolved.append(DocumentReference(id: id, revision: referenceMap[id]!))
					}

					// Update
					documentIDs.remove(id)
				}

		// Add references not found in database
		documentIDs.forEach()
				{ documentReferencesNotResolved.append(DocumentReference(id: $0, revision: referenceMap[$0]!)) }

		return (documentInfos, documentReferencesNotResolved)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func add(_ documentInfos :[DocumentInfo], for documentType :String) {
		// Setup
		let	sqliteTable = self.sqliteTable(for: documentType)
		self.sqliteDatabase.performAsTransaction() {
			// Iterate all document infos
			documentInfos.forEach() {
				// Insert or replace
				sqliteTable.insertOrReplaceRow(
						[
							(tableColumn: sqliteTable.idTableColumn, value: $0.id),
							(tableColumn: sqliteTable.revisionTableColumn, value: $0.revision),
							(tableColumn: sqliteTable.activeTableColumn, value: $0.active ? 1 : 0),
							(tableColumn: sqliteTable.creationDateTableColumn,
									value: $0.creationDate.timeIntervalSince1970),
							(tableColumn: sqliteTable.modificationDateTableColumn,
									value: $0.modificationDate.timeIntervalSince1970),
							(tableColumn: sqliteTable.jsonTableColumn, value: $0.propertyMap.data),
						])
			}

			return .commit
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func sqliteTable(for documentType :String) -> SQLiteTable {
		// Retrieve or create if needed
		var	sqliteTable = self.sqliteTables[documentType]
		if sqliteTable == nil {
			// Create
			let	name = documentType.prefix(1).uppercased() + documentType.dropFirst() + "s"

			sqliteTable =
					self.sqliteDatabase.table(name: name, options: [],
							tableColumns: [
											SQLiteTableColumn("id", .text, [.primaryKey, .notNull, .unique]),
											SQLiteTableColumn("revision", .integer4, [.notNull]),
											SQLiteTableColumn("active", .integer1, [.notNull]),
											SQLiteTableColumn("creationDate", .real, [.notNull]),
											SQLiteTableColumn("modificationDate", .real, [.notNull]),
											SQLiteTableColumn("json", .blob, [.notNull]),
										  ])
			sqliteTable!.create()
			self.sqliteTables[documentType] = sqliteTable
		}

		return sqliteTable!
	}
}
