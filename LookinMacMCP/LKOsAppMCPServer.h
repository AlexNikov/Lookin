#import <Foundation/Foundation.h>
#import "LKOsAppMCPDataSource.h"

NS_ASSUME_NONNULL_BEGIN

/// HTTP MCP listener on macOS (implementation: `LKOsAppMCPServerSwift` in Swift).
@interface LKOsAppMCPServer : NSObject

+ (instancetype)shared;
- (void)startOnPort:(uint16_t)port dataSource:(id<LKOsAppMCPDataSource>)dataSource;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
