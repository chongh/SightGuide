//
//  SceneModel.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import Foundation

struct Scene: Decodable {
    let sceneId: String
    let objs: [SceneItem]
    
    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case objs
    }
}

struct SceneItem: Decodable {
    let objId: Int
    let objName: String
    let type: Int
    let angle: Double
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case objId = "obj_id"
        case objName = "obj_name"
        case type
        case angle
        case text
    }
}

