//
//  NewDownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

public class NewDownloadModel: Codable {
    public var identifier: String {
        (pathId + (programInfo?.programPathId ?? "") + ua).sha1()
    }
    
    public var pathId: String
    public var ua: String
    public var url: String
    public var subtitles: [DownloadSubtitlesModel]?
    public var drm: LicenseServerModel?
    public var videoInfo: VideoInfoModel?
    public var programInfo: ProgramInfoModel?
    public var expireDate: Date?
    public var state: AssetInfo.RAIAVAssetStatus?
    public var playerSource: String?
}

extension NewDownloadModel: ReactDictionaryConvertible, Equatable {
    public static func == (lhs: NewDownloadModel, rhs: NewDownloadModel) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

public struct LicenseServerModel: Codable {
    let type: DRMType?
    let licenseServer: String?
    let licenseToken: String?
}

public enum DRMType: String, Codable {
    case WIDEVINE = "widevine"
    case PLAYREADY = "playready"
    case CLEARKEY = "clearkey"
    case FAIRPLAY = "fairplay"
}

public struct DownloadSubtitlesModel: Codable {
    let language: String   // lingua dei sottotitoli
    let webUrl: String     // url dei sottotitoli
    let localUrl: String?  // url dei sottotitoli locali
}
