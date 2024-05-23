//
//  MDSSQLiteCpp.h
//  Mini Document Storage Tests
//
//  Created by Stevo on 4/16/24.
//

#import "MDSDocumentStorageObjC.h"

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSEphemeralCpp

@interface MDSSQLiteCpp : MDSDocumentStorageObjC

// MARK: Instance methods

- (instancetype) initWithFolderPath:(NSString*) folderPath;

@end

NS_ASSUME_NONNULL_END
