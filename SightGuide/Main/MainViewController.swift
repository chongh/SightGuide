//
//  ViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

final class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func glanceButtonClickedAction(_ sender: Any) {
        let glanceViewController = GlanceViewController()
        navigationController?.pushViewController(glanceViewController, animated: true)
    }
    
    @IBAction func memoryButtonClickedAction(_ sender: Any) {
        let memoryViewController = MemoryViewController()
        navigationController?.pushViewController(memoryViewController, animated: true)
    }
    
    @IBAction func sharingButtonClickedAction(_ sender: Any) {
        let sharingViewController = SharingViewController()
        navigationController?.pushViewController(sharingViewController, animated: true)
    }
    
}

