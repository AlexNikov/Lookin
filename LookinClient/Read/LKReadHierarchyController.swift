//
//  LKReadHierarchyController.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/13.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKReadHierarchyController: LKHierarchyController, LKHierarchyViewDelegate {
    override init(dataSource: LKHierarchyDataSource) {
        super.init(dataSource: dataSource)
        hierarchyView.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func hierarchyView(_ view: LKHierarchyView, needToCancelPreviewOfItem item: LookinDisplayItem) {
        item.noPreview = true
        guard let readSource = dataSource as? LKReadHierarchyDataSource else { return }
        readSource.itemDidChangeNoPreviewRelay.accept(())
    }

    func hierarchyView(_ view: LKHierarchyView, needToShowPreviewOfItem item: LookinDisplayItem) {
        item.enumerateSelfAndAncestors { ancestor, _ in
            if ancestor.noPreview {
                ancestor.noPreview = false
            }
        }
        guard let readSource = dataSource as? LKReadHierarchyDataSource else { return }
        readSource.itemDidChangeNoPreviewRelay.accept(())
    }
}
