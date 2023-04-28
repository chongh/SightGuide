//
//  MemoryCollectionViewCell.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/19.
//

import UIKit

final class MemoryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var innerView: InnerView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var doubleTapAction: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        innerView.layer.borderWidth = 2
        innerView.layer.borderColor = UIColor.systemYellow.cgColor
        
        configureDoubleTapGesture()
    }
    
    func renderLabel(label: Label) {
        titleLabel.text = "\(label.labelName): \(label.duration)s"
        innerView.cell = self
    }
    
    func renderScene(scene: Scene) {
        titleLabel.text = scene.sceneName
        innerView.cell = self
    }
    
    func setStandardBorder() {
        innerView.layer.borderWidth = 2
    }
    
    func setThickenedBorder() {
        innerView.layer.borderWidth = 5
    }
    
    // MARK: - Gestures
    
    private func configureDoubleTapGesture() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(cellDoubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGesture)
    }
    
    @objc private func cellDoubleTapped() {
        doubleTapAction?()
    }

}

final class InnerView: UIView {
    var cell: MemoryCollectionViewCell?
}
