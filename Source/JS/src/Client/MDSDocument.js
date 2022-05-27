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
	setActive(active) { this.info.active = active ? 1 : 0; }
	toggleIsActive() { this.info.active = 1 - this.info.active; }

	get creationDate() { return Date.parse(this.info.creationDate); }			// Date
	get	modificationDate() { return Date.parse(this.info.modificationDate); }	// Date

	updated = {};
	removed = new Set();

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
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	toString() { return JSON.stringify(this.info); }

	// Subclass methods
	//------------------------------------------------------------------------------------------------------------------
	value(property) {
		// Check what the situation is
		if (this.updated[property])
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
	set(property, value) {
		// Check value
		if (value) {
			// Have value
			this.updated[property] = value;
			this.removed.delete(property);
		} else {
			// Don't have value
			delete this.updated[property];
			this.removed.add(property);
		}
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
	updateInfo() {
		// Return info
		return {
			documentID: this.info.documentID,
			updated: this.updated,
			removed: Array.from(this.removed),
			active: this.info.active,
		};
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
	}
}
