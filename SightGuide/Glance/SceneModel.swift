//
//  SceneModel.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import Foundation

struct Scene: Decodable {
    let sceneId: String
    let sceneName: String?
    let objs: [SceneItem]
    
    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case sceneName = "scene_name"
        case objs
    }
}

struct SceneItem: Decodable {
    let objId: Int
    let objName: String
    let type: Int
    let angle: Double
    let text: String
    let position: Position?
    let sceneId: String?
    var labelId: Int?
    
    enum CodingKeys: String, CodingKey {
        case objId = "obj_id"
        case objName = "obj_name"
        case type
        case angle
        case text
        case position
        case sceneId = "scene_id"
        case labelId = "label_id"
    }
}

struct Position: Codable {
    let x0, y0, h, w: CGFloat
}
