//
//  LKMeasureResultLineData.swift
//  Lookin
//
//  Created by Li Kai on 2019/10/24.
//  https://lookin.work
//

import Foundation

class LKMeasureResultHorLineData: NSObject {
    var startX: CGFloat = 0
    var endX: CGFloat = 0
    var y: CGFloat = 0
    var displayValue: CGFloat = 0

    static func data(startX: CGFloat, endX: CGFloat, y: CGFloat, value: CGFloat) -> LKMeasureResultHorLineData {
        let data = LKMeasureResultHorLineData()
        data.startX = startX
        data.endX = endX
        data.y = y
        data.displayValue = value
        return data
    }
}

class LKMeasureResultVerLineData: NSObject {
    var startY: CGFloat = 0
    var endY: CGFloat = 0
    var x: CGFloat = 0
    var displayValue: CGFloat = 0

    static func data(startY: CGFloat, endY: CGFloat, x: CGFloat, value: CGFloat) -> LKMeasureResultVerLineData {
        let data = LKMeasureResultVerLineData()
        data.startY = startY
        data.endY = endY
        data.x = x
        data.displayValue = value
        return data
    }
}
