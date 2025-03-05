//
//  AVPlayerDRMManagerLicenseDownloaderVerimatrix.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import Alamofire

public class AVPlayerDRMManagerLicenseDownloaderVerimatrix : AVPlayerDRMManagerLicenseDownloader {
    public override func download(licenseUrl: String, spcData: Data, completion: @escaping (Data?, Error?) -> Void) {
        let parameters: Parameters = ["spc": spcData.base64EncodedString()]
            
        NetworkManager
            .sessionManager()
            .request(licenseUrl, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                switch response.result {
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
