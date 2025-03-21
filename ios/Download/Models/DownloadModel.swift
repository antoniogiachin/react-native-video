//
//  DownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

class DownloadModel: Codable, ReactDictionaryConvertible {
    var pathId: String
    var ua: String
    var url: String
    var subtitles: [DownloadSubtitlesModel]?
    var drm: LicenseServerModel?
    /// Il video che stiamo scaricando
    var videoInfo: VideoInfoModel
    /// Il programma a cui appartiene il video
    var programInfo: ProgramInfoModel?
    var expireDate: String?
    var state: DownloadState? {
        didSet {
            // Updating bookmark location if needed
            updatePropertiesIfNeeded()
        }
    }
    var playerSource: String? {
        if #available(iOS 16.0, *) {
            location?.path()
        } else {
            location?.path
        }
    }
    
    lazy var identifier: String = {
        (pathId + (programInfo?.programPathId ?? "") + ua).sha1()
    }()
    
    // Internal properties:
    var _ckcData: Data?
    var _bitrate: Double?
    
    /// Downloaded files location, also used to resume a download task after it is paused.
    var location: URL? {
        get {
            if let bookmarkLocation = _bookmarkLocation {
                // Download completed and bookmarked
                var bookmarkDataIsStale = false
                
                let url = try? URL(
                    resolvingBookmarkData: bookmarkLocation,
                    bookmarkDataIsStale: &bookmarkDataIsStale
                )
                
                if let url, bookmarkDataIsStale {
                    // Bookmark data is stale, updating the bookmark location
                    _bookmarkLocation = try? url.bookmarkData()
                    return nil
                }
                
                return url
            }
            
            // The download might be paused
            return _location
        }
        set {
            _location = newValue
        }
    }
    private var _location: URL?
    
    /// Used to persist access to the same file location after the download is completed,
    /// even if the file is moved or renamed by the user.
    private(set) var _bookmarkLocation: Data?
    
    private func updatePropertiesIfNeeded() {
        guard state == .completed else { return }
        
        if _bookmarkLocation == nil {
            _bookmarkLocation = try? _location?.bookmarkData()
        }
        
        if videoInfo.totalBytes == nil || videoInfo.totalBytes == 0 {
            if let size = getSize() {
                videoInfo.totalBytes = size
                videoInfo.bytesDownloaded = videoInfo.totalBytes
            }
        }
    }
    
    init(
        pathId: String,
        ua: String,
        url: String,
        subtitles: [DownloadSubtitlesModel]? = nil,
        drm: LicenseServerModel? = nil,
        videoInfo: VideoInfoModel,
        programInfo: ProgramInfoModel? = nil,
        expireDate: String? = nil,
        state: DownloadState? = nil,
        _ckcData: Data? = nil,
        _bitrate: Double? = nil,
        _location: URL? = nil,
        _bookmarkLocation: Data? = nil
    ) {
        self.pathId = pathId
        self.ua = ua
        self.url = url
        self.subtitles = subtitles
        self.drm = drm
        self.videoInfo = videoInfo
        self.programInfo = programInfo
        self.expireDate = expireDate
        self.state = state
        self._ckcData = _ckcData
        self._bitrate = _bitrate
        self._location = _location
        self._bookmarkLocation = _bookmarkLocation
    }
}

extension DownloadModel: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(identifier.prefix(9))"
    }
}

extension DownloadModel: Equatable {
    static func == (lhs: DownloadModel, rhs: DownloadModel) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

extension DownloadModel {
    private func getSize() -> Int? {
        guard let url = location else {
            return nil
        }
        
        let properties: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
        ]
        
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: url.relativePath),
            includingPropertiesForKeys: properties,
            options: .skipsHiddenFiles,
            errorHandler: nil
        ) else {
            return nil
        }
        
        let urls: [URL] = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.absoluteString.contains(".frag") }
        
        let regularFileResources: [URLResourceValues] = urls
            .compactMap { try? $0.resourceValues(forKeys: Set(properties)) }
            .filter { $0.isRegularFile == true }
        
        let sizes: [Int] = regularFileResources
            .compactMap { $0.totalFileAllocatedSize ?? 0 }
        
        let raw = sizes.reduce(0, +)
        // let formatted = ByteCountFormatter.string(
        //     fromByteCount: Int64(raw),
        //     countStyle: .file
        // )
        
        return raw
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
