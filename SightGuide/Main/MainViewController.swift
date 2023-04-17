//
//  ViewController.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

final class MainViewController: UIViewController {
    @IBOutlet weak var txtUserId: UITextField!
    @IBOutlet weak var btnStart: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        LogHelper.Setup()
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
    
    @IBAction func startButtonClickedAction(_ sender: Any) {
        LogHelper.UserId = txtUserId.text ?? "0"
        txtUserId.resignFirstResponder()
        txtUserId.endEditing(false)
        LogHelper.log.info("Experiment Start For User " + LogHelper.UserId)
        if btnStart.tintColor == .blue {
            btnStart.tintColor = .red
        } else {
            btnStart.tintColor = .blue
        }
    }
    
}

