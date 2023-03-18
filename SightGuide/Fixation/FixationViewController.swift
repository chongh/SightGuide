//
//  FixationViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

class FixationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGreen
        title = "Fixation"
        
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(threeFingerSwipeUp))
        swipeGesture.direction = .up
        swipeGesture.numberOfTouchesRequired = 3
        view.addGestureRecognizer(swipeGesture)
    }

    @objc func threeFingerSwipeUp() {
        dismiss(animated: true, completion: nil)
    }
}
