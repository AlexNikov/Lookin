import Foundation
import LookinShared

/// Peertalk transport surface for the mac Lookin client (`LKAsyncPeerChannel` over `actor PTChannel`).
public protocol LKPeerChannel: AnyObject {
    var targetPort: Int { get }
    var isConnected: Bool { get }
    func sendFrame(
        ofType type: UInt32,
        tag: UInt32,
        withPayload payload: dispatch_data_t?,
        callback: ((NSError?) -> Void)?
    )
    func close()
    func cancel()
}
