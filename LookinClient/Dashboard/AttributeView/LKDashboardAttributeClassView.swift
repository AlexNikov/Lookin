import AppKit
import LookinShared

final class LKDashboardAttributeClassView: LKDashboardAttributeStringArrayView {
    override func stringList(with attribute: LookinAttribute) -> [String] {
        guard case .customObject(let rawValue)? = attribute.value,
              let lists = rawValue as? [[String]] else { return [] }
        return lists.map { rawClassList in
            rawClassList.map { LKSwiftDemangler.completedParse(input: $0) }.joined(separator: "\n")
        }
    }
}
