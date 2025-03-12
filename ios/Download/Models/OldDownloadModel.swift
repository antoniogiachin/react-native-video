//
//  OldDownloadModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

class OldDownloadModel: NSObject, NSCoding, NSSecureCoding {
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public var externalSubtitles: [ExternalSubtitleModel]?
    
    public var ua: String
    
    public var identifier: String {
        return (pathId + programPathId + ua).sha1()
    }
    
    public var pathId: String
    
    public var programPathId: String
    
    public var ckcData: Data?
    
    public var assetStatus: DownloadInfo.RAIAVAssetStatus?
    
    public var bookmarkLocation: Data?
    
    public var _location: URL?
    
    public var location: URL? {
        get {
            /*
             bookmark location is available when download is completed
             */
            if let bookmarkLocation = bookmarkLocation {
                var bookmarkDataIsStale = false
                do {
                    let url = try URL(resolvingBookmarkData: bookmarkLocation,
                                      bookmarkDataIsStale: &bookmarkDataIsStale)
                    
                    if bookmarkDataIsStale {
                        self.bookmarkLocation = try url.bookmarkData()
                        return nil
                    }
                    return url
                } catch {
                    debugPrint("failed to create URL from bookmark with error: \(error)")
                    return nil
                }
            }
            /*
             return nil if bookmark location is nil and download is completed,
             it means that file is deleted from iphone settings
             */
            if assetStatus == .Completed {
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
    
    public var bitrate: Double?
    
    required init?(coder aDecoder: NSCoder) {
        
        self.ua = ""
        self.pathId = ""
        self.programPathId = ""
        
        super.init()
        
        // init data for location
        bookmarkLocation = aDecoder.decodeObject(forKey: "bookmarkLocation") as? Data
        _location = aDecoder.decodeObject(forKey: "_location") as? URL
        ckcData = aDecoder.decodeObject(forKey: "ckcData") as? Data
        
        // init status
        let status = aDecoder.decodeInteger(forKey: "assetStatus")
        
        switch status {
        case 2:
            assetStatus = DownloadInfo.RAIAVAssetStatus.Downloading
        case 3:
            assetStatus = DownloadInfo.RAIAVAssetStatus.Paused
        case 4:
            assetStatus = DownloadInfo.RAIAVAssetStatus.Completed
        default:
            assetStatus = DownloadInfo.RAIAVAssetStatus.Queue
        }
        
        // init metadata
        programPathId = aDecoder.decodeObject(forKey: "_parentPathId") as? String ?? ""
        
        if let location = location, let json = location.lastPathComponent.split(separator: "_").first?.removingPercentEncoding {
            self.pathId = String(json)
        }
    }
    
    func encode(with coder: NSCoder) {
        
    }
}

struct ExternalSubtitleModel: Codable, ReactDictionaryConvertible {
    var id: String?
    var label: String?
    var url: String?
}
