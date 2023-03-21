//
//  NetworkRequester.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/21.
//

import Foundation

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
}

enum APIError: Error {
    case invalidURL
    case requestFailed
    case parsingFailed
}

private let BaseURL = "https://your.api"

final class NetworkRequester {
    
    // MARK: - Glance
    
    static func getScene(completion: @escaping (Result<Scene, APIError>) -> Void) {
        let urlString = "/glance/data"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    static func getIMUData(completion: @escaping (Result<IMUData, APIError>) -> Void) {
        let urlString = "/glance/imu"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    static func postLikeGlanceItem(objId: Int, like: Int, completion: @escaping (Result<Void, APIError>) -> Void) {
        let urlString = "/glance/like"
        
        let params: [String: Any] = [
            "obj_id": objId,
            "like": like
        ]
        
        guard let requestBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            completion(.failure(.parsingFailed))
            return
        }
        
        performRequest(urlString: urlString, method: .post, requestBody: requestBody) { (result: Result<CommonResponse, APIError>) in
            switch result {
            case .success(let response):
                if response.result == 0 {
                    completion(.success(()))
                } else {
                    completion(.failure(.requestFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fixation
    
    static func postFixationData(sceneId: String, completion: @escaping (Result<Scene, APIError>) -> Void) {
        let urlString = "/fixation/data"
        
        let params: [String: Any] = [
            "scene_id": sceneId
        ]
        
        guard let requestBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            completion(.failure(.parsingFailed))
            return
        }
        
        performRequest(urlString: urlString, method: .post, requestBody: requestBody, completion: completion)
    }
    
    // MARK: - Memory
    
    static func getMemoryLabels(completion: @escaping (Result<MemoryResponse, APIError>) -> Void) {
        let urlString = "/memory/labels"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    // MARK: - Common
    
    static func performRequest<T: Codable>(
        urlString: String,
        method: HttpMethod,
        queryParameters: [String: String]? = nil,
        requestBody: Data? = nil,
        completion: @escaping (Result<T, APIError>) -> Void)
    {
        var urlComponents = URLComponents(string: BaseURL + urlString)
        
        if let queryParameters = queryParameters {
            urlComponents?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents?.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = requestBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(.requestFailed))
                return
            }
            
            do {
                let decodedObject = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedObject))
            } catch {
                completion(.failure(.parsingFailed))
            }
        }
        
        task.resume()
    }
    
    static func performRequestForData(url: URL, method: HttpMethod, completion: @escaping (Result<Data, APIError>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(.requestFailed))
                return
            }
            completion(.success(data))
        }
        
        task.resume()
    }
    
}
