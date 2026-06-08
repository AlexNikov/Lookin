import Foundation
import LookinShared

final class LKDashboardSectionViewPool: NSObject {
    private var dequeuedViews = Set<LKDashboardSectionView>()
    private var cache: [String: [LKDashboardSectionView]] = [:]

    func recycleAll() {
        dequeuedViews.removeAll()
    }

    func dequeView(for section: LookinAttributesSection) -> LKDashboardSectionView {
        let key = cacheKey(for: section)
        if cache[key] == nil {
            cache[key] = []
        }
        for view in cache[key] ?? [] {
            if dequeuedViews.contains(view) { continue }
            dequeuedViews.insert(view)
            return view
        }
        let newView = LKDashboardSectionView()
        dequeuedViews.insert(newView)
        cache[key, default: []].append(newView)
        return newView
    }

    private func cacheKey(for section: LookinAttributesSection) -> String {
        if !section.isUserCustom() {
            return section.identifier ?? ""
        }
        let titles = (section.attributes ?? []).map { $0.displayTitle ?? "" }
        return titles.joined(separator: ",")
    }
}
