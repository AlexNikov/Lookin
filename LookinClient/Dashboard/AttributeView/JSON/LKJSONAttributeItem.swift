import Foundation

final class LKJSONAttributeItem: NSObject {
    var titleText: String?
    var desc: String?
    var expanded = true
    var subItems: [LKJSONAttributeItem] = []
    var indentation = 0

    override init() {
        super.init()
        expanded = true
        subItems = []
    }

    func flatItems() -> [LKJSONAttributeItem] {
        var array: [LKJSONAttributeItem] = [self]
        if expanded {
            for obj in subItems {
                obj.indentation = indentation + 1
                array.append(contentsOf: obj.flatItems())
            }
        }
        return array
    }
}
