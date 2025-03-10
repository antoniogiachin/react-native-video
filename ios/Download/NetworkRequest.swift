//
//  NetworkRequest.swift
//  react-native-video
//
//  Created by Davide Balistreri on 10/03/25.
//

import Foundation

typealias HTTPHeaders = [String: String]
typealias Parameters = [String: Any]

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

/// Helper struct to perform simple network requests.
struct NetworkRequest {
    var url: String
    var method: HTTPMethod = .get
    var headers: HTTPHeaders?
    var parameters: Parameters?
    
    func responseJSON(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        perform(responseType: .jsonObject, completion: completion)
    }
    
    func responseString(completion: @escaping (Result<String, Error>) -> Void) {
        perform(responseType: .string, completion: completion)
    }
    
    func responseData(completion: @escaping (Result<Data, Error>) -> Void) {
        perform(responseType: .data, completion: completion)
    }
    
    private enum ResponseType {
        case jsonObject
        case string
        case data
    }
    
    private func perform<T>(
        responseType: ResponseType,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if method == .post, let parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid Response", code: -1, userInfo: nil)))
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "Invalid Status Code: \(httpResponse.statusCode)", code: httpResponse.statusCode, userInfo: nil)))
                return
            }
            
            guard let data else {
                completion(.failure(NSError(domain: "No Data", code: -1, userInfo: nil)))
                return
            }
            
            switch responseType {
            case .jsonObject:
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let result = json as? T {
                        completion(.success(result))
                    } else {
                        completion(.failure(NSError(domain: "Invalid JSON", code: -1, userInfo: nil)))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .string:
                if let string = String(data: data, encoding: .utf8), let result = string as? T {
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "Invalid String", code: -1, userInfo: nil)))
                }
            case .data:
                if let result = data as? T {
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "Invalid Data", code: -1, userInfo: nil)))
                }
            }
        }
        
        task.resume()
    }
}
