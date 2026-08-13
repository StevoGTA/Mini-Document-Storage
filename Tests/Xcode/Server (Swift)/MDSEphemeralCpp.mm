//
//  MDSEphemeralCpp.mm
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/23/23.
//

#import "MDSEphemeralCpp.h"

#import "CMDSEphemeral.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local procs

static	void	noteChangesMade(void* userData) {}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC (Internal)

@property (nonatomic, assign)	CMDSDocumentStorageServer*	documentStorageServer;

@end

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSEphemeralCpp

@implementation MDSEphemeralCpp

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
- (instancetype) init
{
	// Do super
	self = [super init];
	if (self) {
		// Setup
		self.documentStorageServer = new CMDSEphemeral(CMDSEphemeral::Procs(noteChangesMade, nil));

		// Complete setup
		[self completeSetup];
	}

	return self;
}

@end
