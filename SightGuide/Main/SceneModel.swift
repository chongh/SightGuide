//
//  SceneModel.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/18.
//

import Foundation

struct Scene: Codable {
    let sceneId: String
    let sceneName: String?
    var objs: [SceneItem]?
    let labels: [Label]?
    
    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case sceneName = "scene_name"
        case objs
        case labels
    }
}

struct BasicParams: Codable {
    let glanceType: Int
    
    enum CodingKeys: String, CodingKey {
        case glanceType = "glance_type"
    }
}

struct SceneItem: Codable {
    let objId: Int
    let objName: String
    let type: Int
    let angle: Double
    let text: String
    let position: Position?
    let sceneId: String?
    let processedName: String?
    let angles: [Double]?
    var labelId: Int?
    var isRecord: Bool?
    
    enum CodingKeys: String, CodingKey {
        case objId = "obj_id"
        case objName = "obj_name"
        case type
        case angle
        case text
        case position
        case sceneId = "scene_id"
        case processedName = "processed_unique_name"
        case angles
        case labelId = "label_id"
        case isRecord = "is_record"
    }
}

struct Position: Codable {
    let x0, y0, h, w: CGFloat
}

struct Label: Codable {
    let labelId: Int
    let labelName: String
    let labelText: String
    let duration: Int
    let recordName: String?
    
    enum CodingKeys: String, CodingKey {
        case labelId = "label_id"
        case labelName = "label_name"
        case labelText = "label_text"
        case duration
        case recordName = "record_name"
    }
}

struct MemoryResponse: Codable {
    let data: [Scene]
}

struct CommonResponse: Codable {
    let result: Int
}

struct IMUData: Codable {
    let imu: Int
}

struct CreateLabelResponse: Codable {
    let labelId: Int
    
    enum CodingKeys: String, CodingKey {
        case labelId = "label_id"
    }
}
