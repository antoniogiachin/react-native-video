//
//  AVPlayerDRMManagerLicenseDownloaderAzur.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class AVPlayerDRMManagerLicenseDownloaderAzure : AVPlayerDRMManagerLicenseDownloader {
    public override func download(
        licenseUrl: String,
        spcData: Data,
        completion: @escaping (Data?, Error?) -> Void
    ) {
        let headers : HTTPHeaders = ["Content-Type":"application/x-www-form-urlencoded"]
        let parameters : Parameters = ["spc": spcData.base64EncodedString()]

        NetworkRequest(
            url: licenseUrl,
            method: .post,
            headers: headers,
            parameters: parameters
        ).responseString { result in
                switch result {
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
        }
    }
}
