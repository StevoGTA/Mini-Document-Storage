//
//  MDSDocument.js
//
//  Created by Stevo on 5/18/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	uuid = require('uuid');
let	{UuidTool} = require('uuid-tool');

//----------------------------------------------------------------------------------------------------------------------
// MDSDocument
module.exports = class MDSDocument {

	// Properties
	get documentID() { return this.info.documentID; }							// String
	get	revision() { return this.info.revision; }								// Integer

	get isActive() { return this.info.active == 1; }							// Bool
	setActive(active) {
			// Update
			this.info.active = active ? 1 : 0;
			
			// Note updated
			this.activeChanged = true;
		}
	toggleIsActive() {
			// Update
			this.info.active = 1 - this.info.active;
		
			// Note updated
			this.activeChanged = true;
		}

	get creationDate() { return new Date(this.info.creationDate); }				// Date
	get	modificationDate() { return new Date(this.info.modificationDate); }		// Date

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(info) {
		// Check type
		if (info == null) {
			// New
			let uuidBytes = UuidTool.toBytes(UuidTool.newUuid());
			let documentID = btoa(String.fromCharCode(...new Uint8Array(uuidBytes))).slice(0, 22);

			this.info = {documentID: documentID, active: 1, json: {}, attachments: {}};
		} else if ((typeof info) == 'string')
			// Decode
			this.info = JSON.parse(info);
		else 
			// Store
			this.info = info;
		
		// Setup
		this.updated = {};
		this.removed = new Set();
		this.activeChanged = false;
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	toString() { return JSON.stringify(this.info); }

	// Subclass methods
	//------------------------------------------------------------------------------------------------------------------
	value(property) {
		// Check what the situation is
		if (property in this.updated)
			// Have updated value
			return this.updated[property];
		else if (this.removed.has(property))
			// Was removed
			return null;
		else
			// Not updated
			return this.info.json[property];
	}

	//------------------------------------------------------------------------------------------------------------------
	set(property, value = null) {
		// Check value
		if (value != null) {
			// Have value
			this.updated[property] = value;
			this.removed.delete(property);
		} else {
			// Don't have value
			delete this.updated[property];
			this.removed.add(property);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	notePropertyChanged(property) {
		// Updated
		this.updated[property] = this.info.json[property];
		this.removed.delete(property);
	}

	// Internal methods
	//------------------------------------------------------------------------------------------------------------------
	createInfo() {
		// Return info
		return {
			documentID: this.documentID,
			json: this.updated,
		};
	}

	//------------------------------------------------------------------------------------------------------------------
	updateFromCreate(info) {
		// Update
		this.info.revision = info.revision;
		this.info.creationDate = info.creationDate;
		this.info.modificationDate = info.modificationDate;
		this.info.json = this.updated;

		// Reset
		this.updated = {};
		this.removed.clear();
	}

	//------------------------------------------------------------------------------------------------------------------
	hasUpdateInfo() { return (Object.keys(this.updated).length > 0) || (this.removed.size > 0) || this.activeChanged; }

	//------------------------------------------------------------------------------------------------------------------
	updateInfo() {
		// Setup
		let	updateInfo = {documentID: this.info.documentID};

		// Check if have updated properties
		if (Object.keys(this.updated).length > 0)
			// Have updated properties
			updateInfo.updated = this.updated;
		
		// Check if have removed properties
		if (this.removed.size > 0)
			// Have removed properties
			updateInfo.removed = Array.from(this.removed);
		
		// Check if active changed
		if (this.activeChanged)
			// Active changed
			updateInfo.active = this.info.active;
		
		return updateInfo;
	}

	//------------------------------------------------------------------------------------------------------------------
	updateFromUpdate(info) {
		// Update
		this.info.revision = info.revision;
		this.info.active = info.active;
		this.info.modificationDate = info.modificationDate;

		this.info.json = info.json;

		// Reset
		this.updated = {};
		this.removed.clear();
		this.activeChanged = false;
	}
}
