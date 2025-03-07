//
//  DownloadError.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

struct DownloadError: ReactDictionaryConvertible {
    let ua: String
    let pathId: String
    let programPathId: String
    let message: String
    
    init(download: [String: Any], msg: String) {
        pathId = download["pathId"] as? String ?? ""
        programPathId = download["programPathId"] as? String ?? ""
        ua = download["ua"] as? String ?? ""
        message = msg
    }
    
    init(with model: NewDownloadModel, msg: String) {
        pathId = model.pathId
        programPathId = model.programInfo?.programPathId ?? ""
        ua = model.ua
        message = msg
    }
}
