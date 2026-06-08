//
//  LookinDocument.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/26.
//  https://lookin.work
//

import AppKit
import LookinShared

class LookinDocument: NSDocument {
    var hierarchyFile: LookinHierarchyFile?

    override func makeWindowControllers() {
        guard let hierarchyFile else { return }
        let wc = LKReadWindowController(file: hierarchyFile)
        addWindowController(wc)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let hierarchyFile else {
            assertionFailure()
            throw LKLookinClientErrors.inner
        }

        if typeName == "com.lookin.lookin" {
            return try LKWireCodec.archive(hierarchyFile: hierarchyFile)
        }

        throw LKLookinClientErrors.inner
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let file = try LKWireCodec.loadHierarchyFile(from: data)

        if let verifyError = LookinHierarchyFile.verify(file) {
            throw verifyError
        }

        self.hierarchyFile = file
    }
}
