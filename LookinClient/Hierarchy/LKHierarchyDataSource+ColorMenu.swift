import AppKit
import LookinShared

// MARK: - Private helper types

private class LKSelectColorItem: NSObject {
    var title: String = ""
    var color: NSColor?

    static func item(title: String, color: NSColor?) -> LKSelectColorItem {
        let item = LKSelectColorItem()
        item.title = title
        item.color = color
        return item
    }
}

private class LKSelectColorItemsSection: NSObject {
    var title: String = ""
    var items: [LKSelectColorItem] = [] {
        didSet {
            items.sort { $0.title.caseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
}

// MARK: - Color menu

extension LKHierarchyDataSource {
    func alias(forColor color: NSColor?) -> [String]? {
        guard let color else { return nil }
        return colorToAliasMap[color.rgbaString]
    }

    func setUpColors() {
        var colorToAliasMap: [String: [String]] = [:]
        var aliasColorItemsOrSections: [Any] = []

        rawHierarchyInfo?.colorAlias?.forEach { key, colorOrDict in
            if let color = colorOrDict as? NSColor {
                if let colorDesc = color.rgbaString as String? {
                    if colorToAliasMap[colorDesc] == nil {
                        colorToAliasMap[colorDesc] = []
                    }
                    colorToAliasMap[colorDesc]?.append(key)
                }
                aliasColorItemsOrSections.append(LKSelectColorItem.item(title: key, color: color))

            } else if let dict = colorOrDict as? [String: NSColor] {
                let section = LKSelectColorItemsSection()
                section.title = key
                var aliasItems: [LKSelectColorItem] = []

                dict.forEach { colorAliaName, colorObj in
                    if let colorDesc = colorObj.rgbaString as String? {
                        if colorToAliasMap[colorDesc] == nil {
                            colorToAliasMap[colorDesc] = []
                        }
                        colorToAliasMap[colorDesc]?.append(colorAliaName)
                    }
                    aliasItems.append(LKSelectColorItem.item(title: colorAliaName, color: colorObj))
                }

                if !aliasItems.isEmpty {
                    section.items = aliasItems
                    aliasColorItemsOrSections.append(section)
                }
            } else {
                assertionFailure()
            }
        }

        aliasColorItemsOrSections.sort { obj1, obj2 in
            switch (obj1, obj2) {
            case let (item1 as LKSelectColorItem, item2 as LKSelectColorItem):
                return item1.title.caseInsensitiveCompare(item2.title) == .orderedAscending
            case (_ as LKSelectColorItem, _ as LKSelectColorItemsSection):
                return true
            case (_ as LKSelectColorItemsSection, _ as LKSelectColorItem):
                return false
            case let (sec1 as LKSelectColorItemsSection, sec2 as LKSelectColorItemsSection):
                return sec1.title.caseInsensitiveCompare(sec2.title) == .orderedAscending
            default:
                assertionFailure()
                return true
            }
        }

        self.colorToAliasMap = colorToAliasMap
        selectColorMenu = makeMenu(
            withAliasColorItemsOrSections: aliasColorItemsOrSections,
            usingRGBAFormat: LKPreferenceMain().rgbaFormat
        )
    }

    private func makeMenu(
        withAliasColorItemsOrSections aliasColorItemsOrSections: [Any],
        usingRGBAFormat rgbaFormat: Bool
    ) -> NSMenu {
        var menuModel: [Any] = []
        menuModel.append(LKSelectColorItem.item(title: "nil", color: nil))
        menuModel.append(LKSelectColorItem.item(title: "clear color", color: LookinColorRGBAMake(0, 0, 0, 0)))

        let defaultColors: [NSColor] = [
            LookinColorMake(0, 0, 0),
            LookinColorMake(126, 126, 126),
            LookinColorMake(255, 255, 255),
            LookinColorRGBAMake(0, 166, 248, 0.5),
            LookinColorMake(253, 62, 0),
            LookinColorMake(105, 190, 0),
            LookinColorMake(254, 182, 2),
        ]
        let defaultColorItems = defaultColors.enumerated().map { _, value -> LKSelectColorItem in
            let item = LKSelectColorItem()
            item.color = value
            item.title = rgbaFormat ? value.rgbaString : value.hexString
            return item
        }
        menuModel.append(contentsOf: defaultColorItems)

        let defaultItemsCount = menuModel.count
        menuModel.append(contentsOf: aliasColorItemsOrSections)

        let menu = NSMenu()
        for (idx, itemOrSection) in menuModel.enumerated() {
            if idx == defaultItemsCount {
                menu.addItem(.separator())
            }

            if let itemsSection = itemOrSection as? LKSelectColorItemsSection {
                let sectionMenuItem = NSMenuItem()
                sectionMenuItem.image = NSImage(size: NSSize(width: 1, height: 22))
                sectionMenuItem.title = itemsSection.title
                menu.addItem(sectionMenuItem)

                let submenu = NSMenu()
                for subAliasItem in itemsSection.items {
                    submenu.addItem(menuItem(fromColorItem: subAliasItem))
                }
                sectionMenuItem.submenu = submenu

            } else if let colorItem = itemOrSection as? LKSelectColorItem {
                menu.addItem(menuItem(fromColorItem: colorItem))
            } else {
                assertionFailure()
            }
        }

        menu.addItem(.separator())
        let otherItem = NSMenuItem()
        otherItem.image = NSImage(size: NSSize(width: 1, height: 22))
        otherItem.title = NSLocalizedString("Other…", comment: "")
        otherItem.tag = customColorMenuItemTag
        menu.addItem(otherItem)

        menu.addItem(.separator())
        let toggleItem = NSMenuItem()
        toggleItem.image = NSImage(size: NSSize(width: 1, height: 22))
        toggleItem.title = rgbaFormat
            ? NSLocalizedString("Switch color format to HEX", comment: "")
            : NSLocalizedString("Switch color format to RGBA", comment: "")
        toggleItem.tag = toggleColorFormatMenuItemTag
        menu.addItem(toggleItem)

        return menu
    }

    private func menuItem(fromColorItem item: LKSelectColorItem) -> NSMenuItem {
        let image = LKColorIndicatorLayer.image(
            with: item.color,
            shapeSize: NSSize(width: 20, height: 20),
            insets: NSEdgeInsets(top: 4, left: 5, bottom: 4, right: 6)
        )
        let menuItem = NSMenuItem()
        menuItem.image = image
        menuItem.title = item.title
        menuItem.representedObject = item.color
        return menuItem
    }
}
