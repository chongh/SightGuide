//
//  FixationView.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import UIKit

final class FixationItemView: UIView {
    
    @IBOutlet weak var dotView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    // data
    var item: SceneItem?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        dotView.layer.cornerRadius = 5
        dotView.layer.borderWidth = 2
        dotView.layer.borderColor = UIColor.red.cgColor
        setStandardBorder()
    }
    
    func setStandardBorder() {
        layer.borderWidth = 2
    }
    
    func setThickenedBorder() {
        layer.borderWidth = 5
    }
    
    func displayDot() {
        dotView.isHidden = false
        dotView.layer.backgroundColor = UIColor.red.cgColor
    }
    
    func displayEmptyDot() {
        dotView.isHidden = false
        dotView.layer.backgroundColor = UIColor.white.withAlphaComponent(0).cgColor
    }
    
    func renderSceneItem(item: SceneItem)
    {
        self.item = item
        
        titleLabel.text = item.objName
        let color = Specs.colorOfItemType(type: item.type)
        layer.borderColor = color.cgColor
//        dotView.backgroundColor = color
        
//        if item.type == 0 {
//            layer.cornerRadius = min(bounds.width, bounds.height) / 2
//        } else {
//            layer.cornerRadius = 0
//        }
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        
        dotView.isHidden = item.labelId == nil
        if item.isRecord == nil {
            dotView.layer.backgroundColor = UIColor.white.withAlphaComponent(0).cgColor
        } else {
            dotView.layer.backgroundColor = UIColor.red.cgColor
        }
    }
    
    class func loadFromNib() -> FixationItemView {
        let nib = UINib(nibName: "FixationItemView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as! FixationItemView
    }
}
