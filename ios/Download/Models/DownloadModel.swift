//
//  DownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

class DownloadModel: Codable, ReactDictionaryConvertible {
    let pathId: String
    let ua: String
    let url: String
    var subtitles: [DownloadSubtitlesModel]?
    var drm: LicenseServerModel?
    var videoInfo: VideoInfoModel
    var programInfo: ProgramInfoModel?
    var expireDate: Date?
    var state: DownloadState? {
        didSet {
            // Updating bookmark location if needed
            setBookmarkIfNeeded()
        }
    }
    var playerSource: String?
    
    lazy var identifier: String = {
        (pathId + (programInfo?.programPathId ?? "") + ua).sha1()
    }()
    
    // Internal properties:
    var _ckcData: Data?
    var _bitrate: Double?
    /// Used to resume a paused download task.
    private(set) var _location: URL?
    /// Used to persist access to the same file location even if it is moved or renamed by the user, after the download is completed.
    private(set) var _bookmarkLocation: Data?
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
    
    func setBookmarkIfNeeded() {
        if state == .completed, _bookmarkLocation == nil {
            _bookmarkLocation = try? location?.bookmarkData()
        }
    }
    
    var location: URL? {
        get {
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
            } else if state == .completed {
                // Bookmark location is not available but the download is completed:
                // it means that file was deleted by the user from the iPhone settings
                return nil
            } else {
                // Returning the stored location, as the download was paused and it's not completed yet
                return _location
            }
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
    case widevine
    case playready
    case clearkey
    case fairplay
}

struct DownloadSubtitlesModel: Codable {
    let language: String   // lingua dei sottotitoli
    let webUrl: String     // url dei sottotitoli
    let localUrl: String?  // url dei sottotitoli locali
}

enum DownloadState: String, Codable {
    case queued = "QUEUED"
    case downloading = "DOWNLOADING"
    case paused = "PAUSED"
    case completed = "COMPLETED"
}
