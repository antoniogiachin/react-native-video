//
//  OldDownloadModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

public class OldDownloadModel: NSObject, NSCoding, DownloadMetadataProtocol, NSSecureCoding {
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    
    public var externalSubtitles: [RCTExternalSubtitleModel]?
    
    public var ua: String
    
    public var identifier: String {
        return (pathId + programPathId + ua).sha1()
    }
    
    public var pathId: String
    
    public var programPathId: String
    
    public var ckcData: Data?
    
    public var assetStatus: AssetInfo.RAIAVAssetStatus?
    
    public var progress: RCTDownloadProgress?
    
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
                    logger.error("failed to create URL from bookmark with error: \(error)")
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
    
    required public init?(coder aDecoder: NSCoder) {
        
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
            assetStatus = AssetInfo.RAIAVAssetStatus.Downloading
        case 3:
            assetStatus = AssetInfo.RAIAVAssetStatus.Paused
        case 4:
            assetStatus = AssetInfo.RAIAVAssetStatus.Completed
        default:
            assetStatus = AssetInfo.RAIAVAssetStatus.Queue
        }
        
        // init metadata
        programPathId = aDecoder.decodeObject(forKey: "_parentPathId") as? String ?? ""
        
        if let location = location, let json = location.lastPathComponent.split(separator: "_").first?.removingPercentEncoding {
            self.pathId = String(json)
        }
        
    }
    
    
    public func encode(with coder: NSCoder) {
        
    }
    
}
