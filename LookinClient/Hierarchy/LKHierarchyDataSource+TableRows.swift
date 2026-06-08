import LookinShared

// MARK: - Table rows & oid map

extension LKHierarchyDataSource {
    func numberOfRows() -> Int {
        displayingFlatItems?.count ?? 0
    }

    func itemAtRow(_ index: Int) -> LookinDisplayItem? {
        if index < 0 { return nil }
        guard let displayingFlatItems, displayingFlatItems.lookin_hasIndex(index) else { return nil }
        return displayingFlatItems[index]
    }

    func row(forItem item: LookinDisplayItem) -> Int {
        displayingFlatItems?.firstIndex(of: item) ?? NSNotFound
    }

    func displayItem(withOid oid: UInt) -> LookinDisplayItem? {
        oidToDisplayItemMap[oid]
    }

    func rebuildOidToDisplayItemMap() {
        guard let rawFlatItems else {
            oidToDisplayItemMap = [:]
            return
        }
        var map: [UInt: LookinDisplayItem] = [:]
        map.reserveCapacity(rawFlatItems.count * 2)
        for obj in rawFlatItems {
            if let viewObject = obj.viewObject, viewObject.oid != 0 {
                map[viewObject.oid] = obj
            }
            if let layerObject = obj.layerObject, layerObject.oid != 0 {
                map[layerObject.oid] = obj
            }
        }
        oidToDisplayItemMap = map
    }
}
