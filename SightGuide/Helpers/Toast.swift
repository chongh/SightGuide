//
//  Toast.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

extension UIViewController {
    func showToast(message: String, duration: TimeInterval = 1.0) {
        let toastView = UIView()
        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastView.layer.cornerRadius = 10
        toastView.clipsToBounds = true
        
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 0
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        
        toastView.addSubview(toastLabel)
        self.view.addSubview(toastView)
        
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastLabel.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 8),
            toastLabel.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -8),
            toastLabel.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            toastLabel.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),
            
            toastView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 16),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -16),
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            toastView.removeFromSuperview()
        }
    }
}
