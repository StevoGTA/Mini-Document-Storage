//
//  router.js
//
//  Created by Stevo on 1/20/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
import * as association from './association.js';
import * as cache from './cache.js';
import * as collection from './collection.js';
import * as document from './document.js';
import * as index from './index.js';
import * as info from './info.js';
import express from 'express';

// Setup
export let router = express.Router();

// Setup Association routes
router.put('/v1/association/:documentStorageID', association.registerV1);
router.put('/v1/association/:documentStorageID/:name', association.updateV1);
router.get('/v1/association/:documentStorageID/:name', association.getDocumentsV1);
router.get('/v1/association/:documentStorageID/:name/value', association.getValueV1);

// Setup Cache routes
router.put('/v1/cache/:documentStorageID', cache.registerV1);

// Setup Collection routes
router.put('/v1/collection/:documentStorageID', collection.registerV1);
router.head('/v1/collection/:documentStorageID/:name', collection.getDocumentCountV1);
router.get('/v1/collection/:documentStorageID/:name', collection.getDocumentsV1);

// Setup Document routes
router.post('/v1/document/:documentStorageID/:documentType', document.createV1);
router.head('/v1/document/:documentStorageID/:documentType', document.getCountV1);
router.get('/v1/document/:documentStorageID/:documentType', document.getV1);
router.patch('/v1/document/:documentStorageID/:documentType', document.updateV1);
router.post('/v1/document/:documentStorageID/:documentType/:documentID/attachment', document.addAttachmentV1);
router.get('/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID',
		document.getAttachmentV1);
router.patch('/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID',
		document.updateAttachmentV1);
router.delete('/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID',
		document.removeAttachmentV1);

// Setup Index routes
router.put('/v1/index/:documentStorageID', index.registerV1);
router.get('/v1/index/:documentStorageID/:name', index.getDocumentsV1);

// Setup Info routes
router.get('/v1/info/:documentStorageID', info.getV1);
router.post('/v1/info/:documentStorageID', info.setV1);

// Setup Intenral routes
router.post('/v1/internal/:documentStorageID', info.setV1);
