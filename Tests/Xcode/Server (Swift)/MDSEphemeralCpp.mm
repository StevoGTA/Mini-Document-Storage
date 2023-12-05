//
//  MDSEphemeralCpp.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/23/23.
//

#import "MDSEphemeralCpp.h"

#import "CMDSEphemeral.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC (Internal)

@property (nonatomic, assign)	CMDSDocumentStorageServer*	documentStorageServer;

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSEphemeralCpp

@interface MDSEphemeralCpp ()

@end

@implementation MDSEphemeralCpp

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) init
{
	// Do super
	self = [super init];
	if (self) {
		// Setup
		self.documentStorageServer = new CMDSEphemeral();

		// Complete setup
		[self completeSetup];
	}

	return self;
}

@end
