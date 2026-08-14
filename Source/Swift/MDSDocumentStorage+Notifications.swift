//
//  MDSDocumentStorage+Notifications.swift
//  Mini Document Storage
//
//  Created by Stevo on 8/14/26.
//  Copyright © 2026 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorage extension
public extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentCreatedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register a created proc that posts to the notification center
		register(documentCreatedProc: { (document :T) in
			notificationCenter.post(name: MDSDocument.createdNotificationName, object: document)
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentUpdatedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register an updated proc that posts to the notification center
		register(documentUpdatedProc: { (document :T, updatedProperties :Set<String>,
				removedProperties :Set<String>, changedProperties :Set<String>) in
			notificationCenter.post(name: MDSDocument.updatedNotificationName, object: document,
					userInfo: [
						MDSDocument.updatedNotificationUpdatedPropertiesKey: updatedProperties,
						MDSDocument.updatedNotificationRemovedPropertiesKey: removedProperties,
						MDSDocument.updatedNotificationChangedPropertiesKey: changedProperties
					])
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentRemovedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register a removed proc that posts to the notification center
		register(documentRemovedProc: { (document :T) in
			notificationCenter.post(name: MDSDocument.removedNotificationName, object: document)
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentAttachmentCreatedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register an attachment created proc that posts to the notification center
		register(documentAttachmentCreatedProc: { (document :T, attachmentID :String,
				attachmentInfo :MDSDocument.AttachmentInfo) in
			notificationCenter.post(name: MDSDocument.attachmentCreatedNotificationName, object: document,
					userInfo: [
						MDSDocument.attachmentCreatedNotificationAttachmentIDKey: attachmentID,
						MDSDocument.attachmentCreatedNotificationAttachmentInfoKey: attachmentInfo
					])
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentAttachmentUpdatedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register an attachment updated proc that posts to the notification center
		register(documentAttachmentUpdatedProc: { (document :T, attachmentID :String,
				attachmentInfo :MDSDocument.AttachmentInfo) in
			notificationCenter.post(name: MDSDocument.attachmentUpdatedNotificationName, object: document,
					userInfo: [
						MDSDocument.attachmentUpdatedNotificationAttachmentIDKey: attachmentID,
						MDSDocument.attachmentUpdatedNotificationAttachmentInfoKey: attachmentInfo
					])
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func register<T : MDSDocument>(documentAttachmentRemovedNotificationCenter notificationCenter :NotificationCenter,
			for documentType :T.Type) {
		// Register an attachment removed proc that posts to the notification center
		register(documentAttachmentRemovedProc: { (document :T, attachmentID :String) in
			notificationCenter.post(name: MDSDocument.attachmentRemovedNotificationName, object: document,
					userInfo: [MDSDocument.attachmentRemovedNotificationAttachmentIDKey: attachmentID])
		})
	}
}
