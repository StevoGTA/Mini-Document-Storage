//
//  MDSDocumentStorageObjC.h
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/23/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageObjC

@interface MDSDocumentStorageObjC : NSObject

// MARK: Instance methods

- (BOOL) associationRegisterNamed:(NSString*) name fromDocumenType:(NSString*) fromDocumentType
		toDocumentType:(NSString*) toDocumentType error:(NSError**) error;

@end

NS_ASSUME_NONNULL_END
