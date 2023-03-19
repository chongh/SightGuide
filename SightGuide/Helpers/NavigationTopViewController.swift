//
//  NavigationTopViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

extension UIApplication {
    class func navigationTopViewController() -> UIViewController? {
            let nav = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController
            return  nav?.topViewController
        }
}
