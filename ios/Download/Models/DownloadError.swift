//
//  DownloadError.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

struct DownloadError: RCTModelEncodable {
    let ua: String
    let pathId: String
    let programPathId: String
    let message: String
    
    init(downloadInput: NSDictionary, msg: String) {
        pathId = downloadInput["pathId"] as? String ?? ""
        programPathId = downloadInput["programPathId"] as? String ?? ""
        ua = downloadInput["ua"] as? String ?? ""
        message = msg
    }
    
    init(downloadModel: DownloadModel, msg: String) {
        pathId = downloadModel.pathId
        programPathId = downloadModel.programPathId
        ua = downloadModel.ua
        message = msg
    }
    
    
}
