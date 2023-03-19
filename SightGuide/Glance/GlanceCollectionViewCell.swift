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
        borderView.backgroundColor = Specs.colorOfItemType(type: item.type)
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
