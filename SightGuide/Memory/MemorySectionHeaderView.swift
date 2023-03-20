//
//  MemorySectionHeaderView.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/19.
//

import UIKit

class MemorySectionHeaderView: UICollectionReusableView {

    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configureTitle(title: String) {
        titleLabel.text = title
    }
}
