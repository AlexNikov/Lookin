//
//  LookinObject+LookinClient.swift
//  LookinClient
//
//  Created by likai.123 on 2024/1/14.
//  Copyright © 2024 hughkli. All rights reserved.
//

import Foundation
import LookinShared

extension LookinObject {
    var lk_completedDemangledClassName: String {
        LKSwiftDemangler.completedParse(input: rawClassName() ?? "")
    }

    var lk_simpleDemangledClassName: String {
        let name = LKSwiftDemangler.simpleParse(input: rawClassName() ?? "")
        let components = (name as NSString).components(separatedBy: ".")
        return components.last ?? name
    }
}
