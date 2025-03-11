//
//  NewDownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

class NewDownloadModel: Codable {
    var identifier: String {
        (pathId + (programInfo?.programPathId ?? "") + ua).sha1()
    }
    
    var pathId: String
    var ua: String
    var url: String
    var subtitles: [DownloadSubtitlesModel]?
    var drm: LicenseServerModel?
    var videoInfo: VideoInfoModel
    var programInfo: ProgramInfoModel?
    var expireDate: Date?
    var state: DownloadState?
    var playerSource: String?
}

extension NewDownloadModel: ReactDictionaryConvertible, Equatable {
    static func == (lhs: NewDownloadModel, rhs: NewDownloadModel) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

struct LicenseServerModel: Codable {
    let type: DRMType?
    let licenseServer: String?
    let licenseToken: String?
}

enum DRMType: String, Codable {
    case WIDEVINE = "widevine"
    case PLAYREADY = "playready"
    case CLEARKEY = "clearkey"
    case FAIRPLAY = "fairplay"
}

struct DownloadSubtitlesModel: Codable {
    let language: String   // lingua dei sottotitoli
    let webUrl: String     // url dei sottotitoli
    let localUrl: String?  // url dei sottotitoli locali
}

enum DownloadState: String, Codable {
    case downloading = "DOWNLOADING"
    case paused = "PAUSED"
    case completed = "COMPLETED"
}
