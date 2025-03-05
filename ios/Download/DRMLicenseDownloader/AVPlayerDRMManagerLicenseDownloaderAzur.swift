//
//  AVPlayerDRMManagerLicenseDownloaderAzur.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import Alamofire

public class AVPlayerDRMManagerLicenseDownloaderAzure : AVPlayerDRMManagerLicenseDownloader {
    public override func download(licenseUrl: String, spcData: Data, completion: @escaping (Data?, Error?) -> Void) {

        let headers : HTTPHeaders = ["Content-Type":"application/x-www-form-urlencoded"]
        let parameters : Parameters = ["spc": spcData.base64EncodedString()]

        NetworkManager
            .sessionManager()
            .request(licenseUrl, method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: headers)
            .validate(statusCode: 200..<300)
            .responseString(completionHandler: { response in
                switch response.result {
                case .success(let value):
                    
                    var stringData = value
                    
                    if stringData.contains("<ckc>") {
                        stringData = stringData.replacingOccurrences(of: "<ckc>", with: "")
                        stringData = stringData.replacingOccurrences(of: "</ckc>", with: "")
                    }

                    if let newData = Data(base64Encoded: stringData) {
                        completion(newData, nil)
                    } else {
                        completion(nil, CustomError.build(failureReason: "Download Azure failed, data corrupted"))
                    }
                case .failure(let error):
                    completion(nil, error)
                }
            })
    }
}
