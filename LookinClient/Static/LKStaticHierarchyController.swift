//
//  LKStaticHierarchyController.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//

import AppKit
import LookinShared

final class LKStaticHierarchyController: LKHierarchyController, LKHierarchyViewDelegate {
    override init(dataSource: LKHierarchyDataSource) {
        super.init(dataSource: dataSource)
        hierarchyView.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func hierarchyView(_ view: LKHierarchyView, needToCancelPreviewOfItem item: LookinDisplayItem) {
        item.noPreview = true
        guard let staticSource = dataSource as? LKStaticHierarchyDataSource else { return }
        staticSource.itemDidChangeNoPreviewRelay.accept(())
    }

    func hierarchyView(_ view: LKHierarchyView, needToShowPreviewOfItem item: LookinDisplayItem) {
        item.enumerateSelfAndAncestors { ancestor, _ in
            if ancestor.noPreview {
                ancestor.noPreview = false
            }
        }
        guard let staticSource = dataSource as? LKStaticHierarchyDataSource else { return }
        staticSource.itemDidChangeNoPreviewRelay.accept(())
    }
}
