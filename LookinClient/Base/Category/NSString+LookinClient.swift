//
//  NSString+LookinClient.swift
//  Lookin
//
//  Created by Li Kai on 2019/9/29.
//  https://lookin.work
//

import Foundation

extension NSString {
    func lk_capitalizedString() -> String? {
        guard length > 0 else { return nil }
        let str = self as String
        let first = str.prefix(1).uppercased()
        let rest = str.dropFirst()
        return first + rest
    }
}
