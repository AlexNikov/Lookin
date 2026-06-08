import AppKit
import LookinShared

final class LKDashboardAttributeRelationView: LKDashboardAttributeStringArrayView {
    override func stringList(with attribute: LookinAttribute) -> [String] {
        if let cache = attribute.lookin_getBindObject(forKey: "cachedDemangled") as? [String] {
            return cache
        }
        guard case .customObject(let rawValue)? = attribute.value,
              let result = rawValue as? [String] else { return [] }
        let demangled = result.map { demangle($0) }
        attribute.lookin_bindObject(demangled, forKey: "cachedDemangled")
        return demangled
    }

    private func demangle(_ rawText: String) -> String {
        if let match = rawText.range(of: #"\(\s*(\w+)\s*:\s*(\w+)\s*\*\s*\)"#, options: .regularExpression) {
            let nsRange = NSRange(match, in: rawText)
            if let regex = try? NSRegularExpression(pattern: #"\(\s*(\w+)\s*:\s*(\w+)\s*\*\s*\)"#),
               let result = regex.firstMatch(in: rawText, range: NSRange(rawText.startIndex..., in: rawText)),
               result.numberOfRanges == 3 {
                let r1 = result.range(at: 1)
                let r2 = result.range(at: 2)
                let s1 = (rawText as NSString).substring(with: r1)
                let s2 = (rawText as NSString).substring(with: r2)
                let d1 = LKSwiftDemangler.simpleParse(input: s1)
                let d2 = LKSwiftDemangler.simpleParse(input: s2)
                var text = rawText
                text = (text as NSString).replacingCharacters(in: r1, with: d1)
                text = text.replacingOccurrences(of: s2, with: d2)
                return text
            }
            _ = nsRange
        }
        if let regex = try? NSRegularExpression(pattern: #"\(\s*(\w+)\s*\*\s*\)"#),
           let result = regex.firstMatch(in: rawText, range: NSRange(rawText.startIndex..., in: rawText)),
           result.numberOfRanges == 2 {
            let range = result.range(at: 1)
            let rawClassName = (rawText as NSString).substring(with: range)
            let demangled = LKSwiftDemangler.simpleParse(input: rawClassName)
            return (rawText as NSString).replacingCharacters(in: range, with: demangled)
        }
        return rawText
    }
}
