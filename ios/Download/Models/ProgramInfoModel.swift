//
//  ProgramInfoModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

struct VideoInfoModel: Codable {
    let templateImg: String
    let title: String
    let description: String
    let mediaInfo: [MediaItemDetail]?
    var bytesDownloaded: Int?
    var totalBytes: Int?
    let id: String?
}

struct ProgramInfoModel: Codable {
    let templateImg: String
    let title: String
    let description: String
    let mediaInfo: [MediaItemDetail]?
    var bytesDownloaded: Int?
    var totalBytes: Int?
    let id: String?
    
    let programPathId: String?
}

struct MediaItemDetail: Codable {
    let key: String
    let type: String
    let value: String
}
