//
//  AVPlayerDRMManagerLicenseDownloaderNagra.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import Alamofire

public class AVPlayerDRMManagerLicenseDownloaderNagra : AVPlayerDRMManagerLicenseDownloader {
    public override func download(licenseUrl: String, spcData: Data, completion: @escaping (Data?, Error?) -> Void) {
        
        guard let licenseUrl : URL = URL(string: licenseUrl)  else {
            completion(nil, CustomError.build(failureReason: "Download Nagra failed, licenseUrl cannot be nil or empty"))
            return
        }
        
        // extract Authorization from licenseUrl
        guard var queryDict = licenseUrl.queryDictionary, let auth = queryDict["Authorization"], !auth.isEmpty else {
            completion(nil, CustomError.build(failureReason: "Download Nagra failed, 'Authorization' field nil or empty"))
            return
        }

        // remove Authorization from query string
        var urlComponents = URLComponents(string: licenseUrl.absoluteString)
        queryDict.removeValue(forKey: "Authorization")
        if queryDict.isEmpty {
            urlComponents?.queryItems = nil
        }else{
            urlComponents?.queryItems = queryDict.map {
                URLQueryItem(name: $0, value: $1)
            }
        }
        let finalUrl = urlComponents?.url ?? licenseUrl

        let request = NSMutableURLRequest(url: finalUrl)
        request.httpMethod = "POST"
        request.httpBody = spcData
        
        request.addValue(auth, forHTTPHeaderField: "nv-authorizations")
        
        let session = URLSession.shared
        session.dataTask(with: request as URLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let response = response as? HTTPURLResponse, let data = data {
                if response.statusCode == 200 {
                    if let jsonBody = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let ckcMessage = jsonBody["CkcMessage"] as? String, let ckcData = Data(base64Encoded: ckcMessage){
                            completion(ckcData, nil)
                        }else{
                            completion(nil, CustomError.build(failureReason: "Download Nagra failed, error parsing 'CkcMessage' field"))
                        }
                    }else{
                        completion(nil, CustomError.build(failureReason: "Download Nagra failed, error parsing JSON"))
                    }
                }else{
                    completion(nil, CustomError.build(failureReason: "Download Nagra failed, server response \(response.statusCode)"))
                }
            }
        }.resume()
    }
}
