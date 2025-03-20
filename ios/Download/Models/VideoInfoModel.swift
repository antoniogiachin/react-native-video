//
//  VideoInfoModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

struct VideoInfoModel: Codable {
    let templateImg: String
    let title: String
    let description: String
    var mediaInfo: [MediaItemDetail]?
    var bytesDownloaded: Int?
    var totalBytes: Int?
    var id: String?
}

struct ProgramInfoModel: Codable {
    let templateImg: String
    let title: String
    let description: String
    var mediaInfo: [MediaItemDetail]?
    var id: String?
    
    var programPathId: String?
}

struct MediaItemDetail: Codable {
    let key: String
    let type: String
    let value: String
}
