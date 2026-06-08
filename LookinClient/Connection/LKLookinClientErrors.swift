import Foundation
import LookinShared

enum LKLookinClientErrors {
    static let domain = LookinErrorDomain

    static var inner: NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_Inner),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "The operation failed due to an inner error.",
                    comment: ""
                ),
            ]
        )
    }

    static func wireResponseFailed(_ reason: String) -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_Inner),
            userInfo: [
                NSLocalizedDescriptionKey: reason,
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
                    "Rebuild Lookin.app and the iOS demo (pod install in Lookin/ and LookinCustomInfoDemo), then reconnect.",
                    comment: ""
                ),
            ]
        )
    }

    static var noConnect: NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_NoConnect),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "The operation failed due to disconnection with the iOS app.",
                    comment: ""
                ),
            ]
        )
    }

    static var objectNotFound: NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_ObjectNotFound),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "Failed to get target object in iOS app",
                    comment: ""
                ),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
                    "Perhaps the related object was deallocated. You can reload Lookin to get newest data.",
                    comment: ""
                ),
            ]
        )
    }

    static func timeout() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_Timeout),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Request timeout", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
                    "Perhaps your iOS app is paused with breakpoint in Xcode, blocked by other tasks in main thread, or moved to background state.",
                    comment: ""
                ),
            ]
        )
    }

    static func discard() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_Discard),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "The request is discarded due to a newer same request.",
                    comment: ""
                ),
            ]
        )
    }

    static func peerTalk() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_PeerTalk),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "The operation failed due to an inner error.",
                    comment: ""
                ),
            ]
        )
    }

    static func pingFailForBackgroundState() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_PingFailForBackgroundState),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "The operation failed because target iOS app has entered to the background state.",
                    comment: ""
                ),
            ]
        )
    }

    static func serverVersionTooLow() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_ServerVersionTooLow),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "Fail to inspect this iOS app due to a version problem.",
                    comment: ""
                ),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
                    "Please update LookinServer.framework linked with target iOS App to a newer version. Visit the website below to get detailed instructions:\nhttps://lookin.work/faq/server-version-too-low/",
                    comment: ""
                ),
            ]
        )
    }

    static func serverVersionTooHigh() -> NSError {
        NSError(
            domain: domain,
            code: Int(LookinErrCode_ServerVersionTooHigh),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Lookin app version is too low.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
                    "Target iOS app is linked with a higher version LookinServer.framework. Please click \"Lookin\"-\"Check for Updates\" near the top-left corner or visit https://lookin.work to update your Lookin app.",
                    comment: ""
                ),
            ]
        )
    }
}
