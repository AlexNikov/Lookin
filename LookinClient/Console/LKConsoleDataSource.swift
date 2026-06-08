//
//  LKConsoleDataSource.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//

import Foundation
import LookinShared
import RxRelay
import RxSwift

struct LKConsoleRecentObject {
    let object: LookinObject
    let message: String
}

final class LKConsoleDataSource: NSObject {
    private let rowItemsRelay = BehaviorRelay<[LKConsoleDataSourceRowItem]>(value: [])
    var rowItemsObservable: Observable<[LKConsoleDataSourceRowItem]> {
        rowItemsRelay.asObservable()
    }

    var rowItems: [LKConsoleDataSourceRowItem] {
        get { rowItemsRelay.value }
        set { rowItemsRelay.accept(newValue) }
    }

    private let currentObjectRelay = BehaviorRelay<LookinObject?>(value: nil)
    var currentObjectObservable: Observable<LookinObject?> {
        currentObjectRelay.asObservable()
    }

    private(set) var currentObject: LookinObject? {
        get { currentObjectRelay.value }
        set { currentObjectRelay.accept(newValue) }
    }

    private let selectedObjectsRelay = BehaviorRelay<[LookinObject]>(value: [])
    private(set) var selectedObjects: [LookinObject] {
        get { selectedObjectsRelay.value }
        set {
            selectedObjectsRelay.accept(newValue)
            syncConsoleTargetIfNeeded()
        }
    }
    private(set) var recentObjects: [LKConsoleRecentObject] = []

    var isShowingConsole = false {
        didSet { syncConsoleTargetIfNeeded() }
    }

    private let selectorNamesDidUpdateRelay = PublishRelay<Void>()
    var selectorNamesDidUpdateObservable: Observable<Void> {
        selectorNamesDidUpdateRelay.asObservable()
    }

    private var classesToSelsDict: [String: [String]] = [:]
    private let disposeBag = DisposeBag()

    init(hierarchyDataSource: LKHierarchyDataSource) {
        super.init()
        classesToSelsDict = [:]

        let item = LKConsoleDataSourceRowItem()
        item.type = .input
        rowItems = [item]

        hierarchyDataSource.selectedItemObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, item in
                guard let item else {
                    owner.selectedObjects = []
                    return
                }
                var objs: [LookinObject] = []
                if let obj = item.hostViewControllerObject { objs.append(obj) }
                if let obj = item.layerObject { objs.append(obj) }
                if let obj = item.viewObject { objs.append(obj) }
                owner.selectedObjects = objs
            }
            .disposed(by: disposeBag)
    }

    func submit(_ text: String) -> Observable<Void> {
        submit(withObj: currentObject, text: text)
    }

    func submit(withObj obj: LookinObject?, text: String) -> Observable<Void> {
        guard let obj else {
            return .error(LKLookinClientErrors.inner)
        }
        guard !text.isEmpty else {
            return .error(LookinErrorMake(
                NSLocalizedString("Content is empty.", comment: ""),
                ""
            ))
        }
        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            return .error(LKLookinClientErrors.noConnect)
        }
        if text.contains(":") {
            let className = obj.rawClassName() ?? ""
            let address = obj.memoryAddress ?? ""
            let errDesc = String(
                format: NSLocalizedString(
                    "You can click \"Pause\" button near the bottom-left corner in Xcode to pause your iOS app, and input in Xcode console like the contents below:\nexpr [((%@ *)%@) %@]",
                    comment: ""
                ),
                className,
                address,
                text
            )
            return .error(LookinErrorMake(
                NSLocalizedString("Lookin doesn't support invoking methods with arguments yet.", comment: ""),
                errDesc
            ))
        }
        if text.contains(".") {
            return .error(LookinErrorMake(
                NSLocalizedString("Lookin doesn't support this syntax yet. Please input a method or property name.", comment: ""),
                ""
            ))
        }

        return LookinRACSignalRx.observeMainThread(app.invokeMethod(withOid: obj.oid, text: text))
            .do(onSuccess: { [weak self] dict in
                guard let self else { return }
                let returnDescription = dict["description"] as? String
                let returnObject = dict["object"] as? LookinObject

                var rowItems = self.rowItems
                let submitItem = LKConsoleDataSourceRowItem()
                submitItem.type = .submit
                submitItem.normalText = text
                submitItem.highlightText = String(
                    format: "<%@: %@>",
                    obj.lk_simpleDemangledClassName,
                    obj.memoryAddress ?? ""
                )
                rowItems.insert(submitItem, at: rowItems.count - 1)

                if let returnDescription, !returnDescription.isEmpty {
                    let returnItem = LKConsoleDataSourceRowItem()
                    returnItem.type = .return
                    returnItem.normalText = returnDescription
                    rowItems.insert(returnItem, at: rowItems.count - 1)
                }

                if let returnObject {
                    let message = String(
                        format: "<%@: %@> => %@",
                        obj.lk_simpleDemangledClassName,
                        obj.memoryAddress ?? "",
                        text
                    )
                    self.addRecentObject(returnObject, message: message)
                }

                self.rowItems = rowItems
            })
            .map { _ in () }
            .asObservable()
    }

    func makeObjectAsCurrent(_ obj: LookinObject) -> Observable<Void> {
        guard let className = obj.rawClassName(), !className.isEmpty else {
            return .error(LKLookinClientErrors.inner)
        }
        guard LKAppsManager.sharedInstance.inspectingApp != nil else {
            return .error(LKLookinClientErrors.noConnect)
        }
        // Update immediately so the console always reflects the current selection.
        currentObject = obj

        if classesToSelsDict[className] != nil {
            return .just(())
        }

        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            return .just(())
        }

        // Fetch selector names in the background for autocomplete; errors are non-fatal.
        return LookinRACSignalRx.observeMainThread(app.fetchSelectorNames(withClass: className, hasArg: true))
            .do(onSuccess: { [weak self] sels in
                if !sels.isEmpty {
                    self?.classesToSelsDict[className] = sels
                }
                self?.selectorNamesDidUpdateRelay.accept(())
            })
            .catch { [weak self] _ in
                self?.selectorNamesDidUpdateRelay.accept(())
                return .just([])
            }
            .map { _ in () }
            .asObservable()
    }

    func currentObjectSelectorNameList() -> [String]? {
        guard let className = currentObject?.rawClassName() else { return nil }
        return classesToSelsDict[className]
    }

    func fetchSelectorNamesIfNeeded() {
        guard let obj = currentObject,
              let className = obj.rawClassName(), !className.isEmpty,
              classesToSelsDict[className] == nil,
              let app = LKAppsManager.sharedInstance.inspectingApp else { return }

        LookinRACSignalRx.observeMainThread(app.fetchSelectorNames(withClass: className, hasArg: true))
            .do(onSuccess: { [weak self] sels in
                if !sels.isEmpty {
                    self?.classesToSelsDict[className] = sels
                }
                self?.selectorNamesDidUpdateRelay.accept(())
            })
            .catch { [weak self] _ in
                self?.selectorNamesDidUpdateRelay.accept(())
                return .just([])
            }
            .subscribe(onSuccess: { _ in }, onFailure: { _ in })
            .disposed(by: disposeBag)
    }

    func clearHistoryContents() {
        let item = LKConsoleDataSourceRowItem()
        item.type = .input
        rowItems = [item]
    }

    private func addRecentObject(_ object: LookinObject, message: String) {
        if let idx = recentObjects.firstIndex(where: { $0.object.oid == object.oid }) {
            recentObjects.remove(at: idx)
        }
        recentObjects.insert(LKConsoleRecentObject(object: object, message: message), at: 0)
        let maxCount = 5
        if recentObjects.count > maxCount {
            recentObjects.removeLast(recentObjects.count - maxCount)
        }
    }

    private func syncConsoleTargetIfNeeded() {
        guard isShowingConsole, !selectedObjects.isEmpty else { return }
        let pref = LKPreferenceMain()
        if pref.syncConsoleTarget || currentObject == nil {
            makeObjectAsCurrent(selectedObjects.last!)
                .subscribe()
                .disposed(by: disposeBag)
        }
    }
}
