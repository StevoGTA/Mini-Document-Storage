//
//  MDSAssociation.swift
//  Mini Document Storage
//
//  Created by Stevo on 9/27/22.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociation
public class MDSAssociation : Equatable {

	// MARK: GetIntegerValueAction
	public enum GetIntegerValueAction : String {
		case sum = "sum"
	}

	// MARK: Item
	public struct Item : Equatable {

		// MARK: Properties
		let	fromDocumentID :String
		let	toDocumentID :String
	}

	// MARK: Update
	public struct Update {

		// MARK: Action
		public enum Action : String {
			case add = "add"
			case remove = "remove"
		}

		// MARK: Properties
		let	action :Action
		let	item :Item

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static public func add(from fromDocument :MDSDocument, to toDocument :MDSDocument) -> Update {
			return Update(.add, fromDocumentID: fromDocument.id, toDocumentID: toDocument.id)
		}

		//--------------------------------------------------------------------------------------------------------------
		static public func remove(from fromDocument :MDSDocument, to toDocument :MDSDocument) -> Update {
			return Update(.remove, fromDocumentID: fromDocument.id, toDocumentID: toDocument.id)
		}

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(_ action :Action, fromDocumentID :String, toDocumentID :String) {
			// Store
			self.action = action
			self.item = Item(fromDocumentID: fromDocumentID, toDocumentID: toDocumentID)
		}
	}

	// MARK: Properties
	let	name :String
	let	fromDocumentType :String
	let	toDocumentType :String

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, fromDocumentType :String, toDocumentType :String) {
		// Store
		self.name = name
		self.fromDocumentType = fromDocumentType
		self.toDocumentType = toDocumentType
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	public static func == (lhs :MDSAssociation, rhs :MDSAssociation) -> Bool { lhs.name == rhs.name }
}
