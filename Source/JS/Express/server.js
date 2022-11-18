//
//  server.js
//
//  Created by Stevo on 1/20/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
import express from 'express';
import {DocumentStorage} from 'mini-document-storage/src/Server/package';
import MySQLToolbox from 'mysql-toolbox';
import {router} from './router.js';

// Setup
let	port = process.env.PORT;

// Setup Express
let	app = express();
app.use(express.json());
app.use('/', router);
app.listen(port, () => console.log(`listening on ${port}`));

// Setup DocumentStorage
app.locals.documentStorage =
		new DocumentStorage(
				() =>
						{ return new MySQLToolbox.StatementPerformer(
								{
									host: process.env.MYSQL_HOST,
									user: process.env.MYSQL_USER,
									password: process.env.MYSQL_PASSWORD,
									multipleStatements: true,
								})
						},
				{},
				{},
				{});
