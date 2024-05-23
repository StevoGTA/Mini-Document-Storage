//
//  MDSSQLiteCpp.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 4/16/24.
//

#import "MDSSQLiteCpp.h"

#import "CMDSSQLite.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC (Internal)

@property (nonatomic, assign)	CMDSDocumentStorageServer*	documentStorageServer;

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSSQLiteCpp

@implementation MDSSQLiteCpp

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) initWithFolderPath:(NSString*) folderPath
{
	// Do super
	self = [super init];
	if (self) {
		// Setup
		self.documentStorageServer =
				new CMDSSQLite(CFolder(CFilesystemPath(CString((__bridge CFStringRef) folderPath))));

		// Complete setup
		[self completeSetup];
	}

	return self;
}

@end
