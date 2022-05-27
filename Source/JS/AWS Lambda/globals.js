//
//  globals.js
//
//  Created by Stevo on 5/12/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let {DocumentStorage} = require('mini-document-storage');
let	MySQLToolbox = require('mysql-toolbox');

// Must reference here as the auto-system doesn't figure to pull them in
let	uuid = require('uuid');

// Setup DocumentStorage
exports.documentStorage =
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
