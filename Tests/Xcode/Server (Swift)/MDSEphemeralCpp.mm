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

@property (nonatomic, assign)	CMDSDocumentStorage*	documentStorage;

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
		self.documentStorage = new CMDSEphemeral();
	}

	return self;
}

@end
