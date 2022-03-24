//
//  server.js
//
//  Created by Stevo on 1/20/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	express = require('express');
let DocumentStorage = require('mini-document-storage');
let	MySQLToolbox = require('mysql-toolbox');
let	routes = require('./routes');

// Setup
let	port = process.env.PORT;

// Setup Express
let	app = express();
app.use(express.json());
app.use('/', routes);
app.listen(port, () => console.log(`listening on ${port}`));

// Setup DocumentStorage
app.locals.documentStorage =
		new DocumentStorage(
				new MySQLToolbox.StatementPerformer(
						{
							host: process.env.MYSQL_HOST,
							user: process.env.MYSQL_USER,
							password: process.env.MYSQL_PASSWORD,
							multipleStatements: true,
						}));
