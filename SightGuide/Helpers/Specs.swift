//
//  Specs.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import Foundation
import UIKit

final class Specs {
    static func colorOfItemType(type: Int) -> UIColor {
        switch type {
        case 0:
            return UIColor.systemRed
        case 1:
            return UIColor.systemYellow
        case 2:
            return UIColor.systemBlue
        case 3:
            return UIColor.systemGreen
        default:
            return UIColor.white
        }
    }
}
