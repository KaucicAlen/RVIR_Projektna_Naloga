//
//  PathfindingManager.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import Foundation

class PathfindingManager {
    static let shared = PathfindingManager()
    
    // TODO: Update this to your server URL
    private let serverURL = "http://localhost:3001"
    
    private init() {}
    
    // MARK: - Pathfinding Request
    func getPath(from start: (x: Float, z: Float), to end: (x: Float, z: Float), completion: @escaping ([SIMD3<Float>]?, Error?) -> Void) {
        let endpoint = "\(serverURL)/api/getPath"
        
        guard let url = URL(string: endpoint) else {
            completion(nil, PathfindingError.invalidURL)
            return
        }
        
        let requestBody: [String: Any] = [
            "start": [start.x, start.z],
            "end": [end.x, end.z]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, PathfindingError.invalidJSON)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, PathfindingError.invalidResponse)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("HTTP Error: \(httpResponse.statusCode)")
                completion(nil, PathfindingError.httpError(httpResponse.statusCode))
                return
            }
            
            guard let data = data else {
                completion(nil, PathfindingError.noData)
                return
            }
            
            do {
                let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                guard let pathArray = responseJSON?["path"] as? [[Float]] else {
                    print("Invalid response format")
                    completion(nil, PathfindingError.invalidResponseFormat)
                    return
                }
                
                // Convert to SIMD3 coordinates
                let waypoints = pathArray.map { coord -> SIMD3<Float> in
                    let x = coord.count > 0 ? coord[0] : 0
                    let z = coord.count > 1 ? coord[1] : 0
                    
                    return SIMD3<Float>(x, 0, z)
                }
                
                print("Successfully received \(waypoints.count) waypoints from server")
                completion(waypoints, nil)
                
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(nil, PathfindingError.jsonParsingError)
            }
        }.resume()
    }
}

// MARK: - Error Handling
enum PathfindingError: LocalizedError {
    case invalidURL
    case invalidJSON
    case invalidResponse
    case httpError(Int)
    case noData
    case invalidResponseFormat
    case jsonParsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidJSON:
            return "Failed to encode request data"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .noData:
            return "No data received from server"
        case .invalidResponseFormat:
            return "Invalid response format from server"
        case .jsonParsingError:
            return "Failed to parse server response"
        }
    }
}
