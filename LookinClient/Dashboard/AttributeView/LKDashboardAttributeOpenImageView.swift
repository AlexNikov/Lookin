import AppKit
import LookinShared
import RxSwift

final class LKDashboardAttributeOpenImageView: LKDashboardAttributeView {
    private var control: LKTextControl!
    private let disposeBag = DisposeBag()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.cornerRadius = DashboardCardControlCornerRadius
        borderColors = LKColorsCombine(LookinColorMake(181, 181, 181), LookinColorMake(83, 83, 83))

        control = LKTextControl()
        control.adjustAlphaWhenClick = true
        control.label.stringValue = NSLocalizedString("Open Image with Preview…", comment: "")
        control.label.font = NSFontMake(11)
        control.addTarget(self, clickAction: #selector(handleClick))
        addSubview(control)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func layout() {
        super.layout()
        lk(control).fullFrame()
    }

    override func renderWithAttribute() {}

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        NSSize(width: limitedSize.width, height: LKNumberInputHorizontalHeight)
    }

    @objc private func handleClick() {
        guard case .customObject(let rawValue)? = attribute?.value,
              let imageViewOidNum = rawValue as? NSNumber else {
            AlertError(LKLookinClientErrors.inner, window)
            assertionFailure()
            return
        }
        let imageViewOid = imageViewOidNum.uintValue
        guard dashboardViewController?.isStaticMode == true else {
            AlertErrorText(
                NSLocalizedString("The feature is not available in current mode.", comment: ""),
                NSLocalizedString("You must connect Lookin with target iOS app before using this feature.", comment: ""),
                window
            )
            return
        }
        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            AlertError(LKLookinClientErrors.noConnect, window)
            return
        }
        LookinRACSignalRx.observeMainThread(app.fetchImage(withImageViewOid: imageViewOid))
            .subscribe(with: self, onSuccess: { owner, imageData in
                guard !imageData.isEmpty else {
                    AlertErrorText(
                        NSLocalizedString("Operation failed. The image property value of selected UIImageView is nil.", comment: ""),
                        "",
                        owner.window
                    )
                    return
                }
                let fileName = String(format: "%.0f", Date().timeIntervalSince1970)
                let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("Lookin_UIImageView_\(fileName).png")
                do {
                    try imageData.write(to: URL(fileURLWithPath: filePath))
                } catch {
                    assertionFailure()
                    AlertError(error as NSError, owner.window)
                    return
                }
                let previewURL = URL(fileURLWithPath: "/System/Applications/Preview.app")
                NSWorkspace.shared.open([URL(fileURLWithPath: filePath)], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration())
                if LKHelper.sharedInstance.tempImageFiles == nil {
                    LKHelper.sharedInstance.tempImageFiles = NSMutableArray()
                }
                LKHelper.sharedInstance.tempImageFiles?.add(filePath)
            }, onFailure: { owner, error in
                AlertError(error as NSError, owner.window)
            })
            .disposed(by: disposeBag)
    }
}
