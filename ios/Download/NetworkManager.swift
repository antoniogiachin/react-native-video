//
//  NetworkManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import Alamofire


public class NetworkManager {
    
    public static var shared : NetworkManager = NetworkManager()
    
    private init() {}
    
    public static var _sessionManager: Alamofire.Session = {
        let configuration = URLSessionConfiguration.af.default
        
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        
        let delegate = SessionDelegate()
        let alamofireManager = Alamofire.Session(configuration: configuration, delegate: delegate, rootQueue: DispatchQueue(label:"org.alamofire.session.rootQueue"), startRequestsImmediately: true, requestQueue: nil, serializationQueue: nil, interceptor: nil, serverTrustManager: nil, redirectHandler: nil, cachedResponseHandler: nil, eventMonitors: [])
        return alamofireManager
    }()
    
    public class func sessionManager() -> Alamofire.Session {
        return _sessionManager
    }

    public func getModel<T : Decodable>(with url: String, headers requestHeaders: [String:String] = [:], success: @escaping (T) -> Void, error: @escaping (Error) -> ()) {
        
        NetworkManager.sessionManager()
            .request(url, headers: HTTPHeaders(requestHeaders))
            .validate(statusCode: 200..<400)
            .responseDecodable(of: T.self) { (response) in
                
                switch response.result {
                case .success(let value):
                    
                    success(value)
                    
                case .failure(let responseError):
                    
                    //dump(responseError)
                    
                    switch responseError {
                    case .sessionTaskFailed(let sessionTaskError):
                        let nserr = sessionTaskError as NSError
                        // -999 is request cancel by user
                        if nserr.code != -999 {
                            error(responseError)
                        }
                    default:
                        error(responseError)
                    }
                }
            }
    }
    
    func mergeHeaders(headersR: [String:String], headersL: [String:String] ) -> [String:String] {
        var finalHeaders : [String:String] = [:]
        
        headersR.forEach { (key, value) in
            finalHeaders[key] = value
        }
        
        headersL.forEach { (key, value) in
            finalHeaders[key] = value
        }
        
        return finalHeaders
    }
    
    public func execRaw<T: Encodable>(with url: String, method: HTTPMethod, params requestParams: T? = nil, parameterEncoder: ParameterEncoder, headers requestHeaders: [String:String] = [:], isAuthenticated: Bool = true, success: @escaping (Any) -> Void, error: @escaping (Error) -> (), maxRetry: Int = 1) {
        

        NetworkManager.sessionManager()
            .request(url, method: method, parameters: requestParams ?? [:] as! T, encoder: parameterEncoder, headers: HTTPHeaders(requestHeaders))
            .validate(statusCode: 200..<400)
            .responseJSON() { (response) in

                switch response.result {
                case .success(let value):
                    success(value)
                case .failure(let responseError):
                    error(responseError)
                }
                
            }
    }
    
    public func rawGet(with url: String, params requestParams: [String:String]? = nil, parameterEncoder: ParameterEncoder = URLEncodedFormParameterEncoder(destination: .methodDependent), headers requestHeaders: [String:String] = [:], isAuthenticated: Bool = true, success: @escaping (Any) -> Void, error: @escaping (Error) -> ()) {
        execRaw(with: url, method: .get, params: requestParams, parameterEncoder: parameterEncoder, headers: requestHeaders, isAuthenticated: isAuthenticated, success: success, error: error)
    }

    public func rawPost<T: Encodable>(with url: String, params requestParams: T, parameterEncoder: ParameterEncoder = URLEncodedFormParameterEncoder(destination: .methodDependent), headers requestHeaders: [String:String] = [:], isAuthenticated: Bool = true, success: @escaping (Any) -> Void, error: @escaping (Error) -> ()) {
        execRaw(with: url, method: .post, params: requestParams, parameterEncoder: parameterEncoder, headers: requestHeaders, isAuthenticated: isAuthenticated, success: success, error: error)
    }
    
}
