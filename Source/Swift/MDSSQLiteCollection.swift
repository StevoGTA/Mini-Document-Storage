//
//  MDSSQLiteCollection.swift
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import SQLite3

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteCollection
class MDSSQLiteCollection {

	// MARK: Properties
//	let	id :String
	static	private	let	idTableColumn =
								SQLiteTableColumn("id", .integer(size: nil, default: nil),
										[.primaryKey, .autoincrement])
	static	private	let	nameTableColumn = SQLiteTableColumn("name", .text(size: nil, default: nil), [.notNull, .unique])
	static	private	let	typeTableColumn = SQLiteTableColumn("type", .text(size: nil, default: nil), [.notNull])
	static	private	let	versionTableColumn = SQLiteTableColumn("version", .integer(size: 2, default: nil), [.notNull])
	static	private	let	lastRevisionColumnInfo =
								SQLiteTableColumn("lastRevision", .integer(size: 4, default: nil), [.notNull])

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func masterTable(for database :SQLiteDatabase) -> SQLiteTable {
		// Return table
		return database.table(name: "Collections", options: [],
				tableColumns: [
								self.idTableColumn,
								self.nameTableColumn,
								self.typeTableColumn,
								self.versionTableColumn,
								self.lastRevisionColumnInfo,
							  ])
	}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
//	init(id :String) {
//		// Store
//		self.id = id
//	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
}
