#import <Foundation/Foundation.h>
#import "LKOsAppMCPDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface LKOsAppMCPHandler : NSObject

@property (nonatomic, weak, nullable) id<LKOsAppMCPDataSource> dataSource;

/// Returns JSON body data. Sets *statusCode (200 or error code).
- (NSData *)handleMethod:(NSString *)method
                    path:(NSString *)path
                    body:(nullable NSData *)body
              statusCode:(NSInteger *)statusCode;

@end

NS_ASSUME_NONNULL_END
