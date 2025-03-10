//
//  AVPlayerDRMManagerLicenseDownloaderVerimatrix.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class AVPlayerDRMManagerLicenseDownloaderVerimatrix : AVPlayerDRMManagerLicenseDownloader {
    public override func download(
        licenseUrl: String,
        spcData: Data,
        completion: @escaping (Data?, Error?) -> Void
    ) {
        let parameters: Parameters = ["spc": spcData.base64EncodedString()]
        
        NetworkRequest(
            url: licenseUrl,
            method: .post,
            parameters: parameters
        ).responseJSON { result in
                switch result {
                case .success(let value):
                    //print(response)
                    if let respJSON = value as? NSDictionary, let respString = respJSON["ckc"] as? String, let ckcData = Data(base64Encoded: respString) {
                        completion(ckcData, nil)
                    }else {
                        completion(nil, CustomError.build(failureReason: "Download Verimatrix failed, data corrupted"))
                    }
                case .failure(let error):
                    completion(nil, error)
                }
        }
    }
}
