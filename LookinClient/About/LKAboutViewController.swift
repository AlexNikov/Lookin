//
//  LKAboutViewController.swift
//  LookinClient
//
//  Created by 李凯 on 2019/10/30.
//  Copyright © 2019 hughkli. All rights reserved.
//

import AppKit
import LookinShared

class LKAboutViewController: LKBaseViewController {
    private var logoImageView: NSImageView!
    private var titleLabel: LKLabel!
    private var versionLabel: LKLabel!
    private var photoImageView: NSImageView!
    private var photoMaskView: LKBaseView!
    private var photoName = ""
    private var maskFinalAlpha: CGFloat = 0

    override init(containerView view: NSView?) {
        let data: [[String: Any]] = [
            ["name": "photo0", "alpha": 0.85],
            ["name": "photo1", "alpha": 0.85],
            ["name": "photo2", "alpha": 0.7],
            ["name": "photo3", "alpha": 0.8],
        ]
        let dataIdx = Int(arc4random_uniform(UInt32(data.count)))
        photoName = data[dataIdx]["name"] as! String
        maskFinalAlpha = data[dataIdx]["alpha"] as! CGFloat
        super.init(containerView: view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()

        photoImageView = NSImageView()
        photoImageView.image = NSImageMake(photoName)
        photoImageView.imageScaling = .scaleAxesIndependently
        containerView.addSubview(photoImageView)

        photoMaskView = LKBaseView()
        photoMaskView.backgroundColors = LKColorsCombine(.white, .black)
        photoMaskView.alphaValue = 1
        containerView.addSubview(photoMaskView)

        logoImageView = NSImageView()
        logoImageView.image = NSImageMake("logo_jump")
        logoImageView.animates = true
        containerView.addSubview(logoImageView)

        titleLabel = LKLabel()
        titleLabel.stringValue = "Lookin"
        titleLabel.textColors = LKColorsCombine(.black, .white)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        containerView.addSubview(titleLabel)

        let dotVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let numberVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        versionLabel = LKLabel()
        versionLabel.stringValue = "Version \(dotVersion) (\(numberVersion))"
        versionLabel.textColors = LKColorsCombine(.black, .white)
        versionLabel.font = NSFontMake(13)
        containerView.addSubview(versionLabel)

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        lk(photoImageView, photoMaskView).fullFrame()
        lk(logoImageView).width(100).height(88).horAlign()
        lk(titleLabel).sizeToFit().horAlign().y(logoImageView.frame.maxY - 6)
        lk(versionLabel).sizeToFit().horAlign().y(titleLabel.frame.maxY + 3)
        lk(logoImageView, titleLabel, versionLabel).groupVerAlign().offsetY(-10)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.aboutAutoClose) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 8
                self.photoMaskView.animator().alphaValue = self.maskFinalAlpha
            }
        }
    }
}
