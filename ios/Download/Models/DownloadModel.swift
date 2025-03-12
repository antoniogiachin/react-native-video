//
//  DownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

class DownloadModel: Codable, ReactDictionaryConvertible {
    var identifier: String {
        (pathId + (programInfo?.programPathId ?? "") + ua).sha1()
    }
    
    let pathId: String
    let ua: String
    let url: String
    var subtitles: [DownloadSubtitlesModel]?
    var drm: LicenseServerModel?
    var videoInfo: VideoInfoModel
    var programInfo: ProgramInfoModel?
    var expireDate: Date?
    var state: DownloadState? /* {
        didSet {
            // FIXME
            setBookmark()
        }
    } */
    var playerSource: String?
    
    // Old properties:
    var _ckcData: Data?
    var _bitrate: Double?
    var _location: URL?
    var _bookmarkLocation: Data?
}

// MARK: - Retrocompatibility

extension DownloadModel {
    // TODO
    //    convenience init(old: OldDownloadModel) {
    //        self.init(
    //            pathId: old.pathId,
    //            ua: old.ua,
    //            url: "",
    //            videoInfo: VideoInfoModel(
    //                templateImg: "",
    //                title: "",
    //                description: ""
    //            ),
    //            state: .completed
    //        )
    //        // programInfo = ProgramInfoModel(
    //        //     programPathId: old.programPathId
    //        // )
    //        _ckcData = old.ckcData
    //        _location = old._location
    //        _bookmarkLocation = old.bookmarkLocation
    //    }
    
    private func setBookmark() {
        if _bookmarkLocation == nil, state == .completed {
            _bookmarkLocation = try? location?.bookmarkData()
        }
    }
    
    public var location: URL? {
        get {
            /*
             bookmark location is available when download is completed
             */
            if let bookmarkLocation = _bookmarkLocation {
                var bookmarkDataIsStale = false
                
                let url = try? URL(
                    resolvingBookmarkData: bookmarkLocation,
                    bookmarkDataIsStale: &bookmarkDataIsStale
                )
                
                if let url, bookmarkDataIsStale {
                    _bookmarkLocation = try? url.bookmarkData()
                    return nil
                }
                return url
            }
            
            /*
             return nil if bookmark location is nil and download is completed,
             it means that file is deleted from iphone settings
             */
            if state == .completed {
                return nil
            }
            
            /*
             return stored location when download file is paused, it needs to resume caching task
             */
            return _location
        }
        set {
            _location = newValue
        }
    }
}

extension DownloadModel: Equatable {
    static func == (lhs: DownloadModel, rhs: DownloadModel) -> Bool {
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
