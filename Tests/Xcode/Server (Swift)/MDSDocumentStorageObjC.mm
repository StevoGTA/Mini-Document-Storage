//
//  MDSDocumentStorageObjC.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/24/23.
//

#import "MDSDocumentStorageObjC.h"

#import "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC ()

@property (nonatomic, assign)	CMDSDocumentStorage*	documentStorage;

@end

@implementation MDSDocumentStorageObjC

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (void) dealloc
{
	// Cleanup
	Delete(self.documentStorage);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error
{
	// Setup

	return FALSE;
}

@end
