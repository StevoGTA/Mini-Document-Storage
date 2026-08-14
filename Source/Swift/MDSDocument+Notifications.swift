//
//  MDSDocument+Notifications.swift
//  Mini Document Storage
//
//  Created by Stevo on 8/14/26.
//  Copyright © 2026 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument extension
extension MDSDocument {

	// MARK: Notification names
	/*
		Sent when a document has been created
			object is the MDSDocument

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	createdNotificationName = Notification.Name("MDSDocument.created")

	/*
		Sent when a document has been updated
			object is the MDSDocument
			userInfo contains the following keys:
				updatedProperties: Set<String> of properties written
				removedProperties: Set<String> of properties removed
				changedProperties: Set<String>, the union of the two

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	updatedNotificationName = Notification.Name("MDSDocument.updated")
	static	public	let	updatedNotificationUpdatedPropertiesKey = "updatedProperties"
	static	public	let	updatedNotificationRemovedPropertiesKey = "removedProperties"
	static	public	let	updatedNotificationChangedPropertiesKey = "changedProperties"

	/*
		Sent when a document has been removed
			object is the MDSDocument

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	removedNotificationName = Notification.Name("MDSDocument.removed")

	/*
		Sent when a document attachment has been created
			object is the MDSDocument
			userInfo contains the following keys:
				attachmentID: String of the created attachment
				attachmentInfo: MDSDocument.AttachmentInfo of the created attachment

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	attachmentCreatedNotificationName = Notification.Name("MDSDocument.attachmentCreated")
	static	public	let	attachmentCreatedNotificationAttachmentIDKey = "attachmentID"
	static	public	let	attachmentCreatedNotificationAttachmentInfoKey = "attachmentInfo"

	/*
		Sent when a document attachment has been updated
			object is the MDSDocument
			userInfo contains the following keys:
				attachmentID: String of the updated attachment
				attachmentInfo: MDSDocument.AttachmentInfo of the updated attachment

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	attachmentUpdatedNotificationName = Notification.Name("MDSDocument.attachmentUpdated")
	static	public	let	attachmentUpdatedNotificationAttachmentIDKey = "attachmentID"
	static	public	let	attachmentUpdatedNotificationAttachmentInfoKey = "attachmentInfo"

	/*
		Sent when a document attachment has been removed
			object is the MDSDocument
			userInfo contains the following keys:
				attachmentID: String of the removed attachment

		Since NotificationCenter matches object by pure identity ("==="), if document matching is required, register
			with "object: nil" and compare "($0.object as? MDSDocument)?.id == {tracked id}".
	*/
	static	public	let	attachmentRemovedNotificationName = Notification.Name("MDSDocument.attachmentRemoved")
	static	public	let	attachmentRemovedNotificationAttachmentIDKey = "attachmentID"
}
