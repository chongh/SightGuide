//
//  GlanceCollectionViewCell.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

final class GlanceCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var borderView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    var doubleTapAction: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        configureDoubleTapGesture()
    }
    
    func renderSceneItem(item: SceneItem)
    {
        titleLabel.text = item.objName
        subtitleLabel.text = item.text
        borderView.backgroundColor = Self.colorOfItemType(type: item.type)
    }
    
    static func colorOfItemType(type: Int) -> UIColor {
        switch type {
        case 1:
            return UIColor.yellow
        case 2:
            return UIColor.blue
        case 3:
            return UIColor.green
        default:
            return UIColor.white
        }
    }
    
    private func configureDoubleTapGesture() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(cellDoubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGesture)
    }
    
    @objc private func cellDoubleTapped() {
        doubleTapAction?()
    }
}
