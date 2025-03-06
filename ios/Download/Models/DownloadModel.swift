//
//  DownloadModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class DownloadModel: DownloadMetadataProtocol, Decodable, RCTModelEncodable {
    
    public var identifier: String {
        return (pathId + programPathId + ua).sha1()
    }
    
    public var pathId: String
    
    public var programPathId: String
    
    public var ua: String
    
    public var ckcData: Data?
    
  public var assetStatus: AssetInfo.RAIAVAssetStatus? {
        didSet {
            setBookmark()
        }
    }
    
    public var progress: RCTDownloadProgress?
    
    private var _location: URL?
    
    private var bookmarkLocation: Data?
    
    public var externalSubtitles: [RCTExternalSubtitleModel]?
    
    public var bitrate: Double?
    
    public init(pathId: String, programPathId: String, user: String) {
        self.pathId = pathId
        self.programPathId = programPathId
        self.ua = user
    }
    
    public init(old: OldDownloadModel) {
        self.pathId = old.pathId
        self.programPathId = old.programPathId
        self.ua = old.ua
        self.ckcData = old.ckcData
        self.assetStatus = old.assetStatus
        self._location = old._location
        self.bookmarkLocation = old.bookmarkLocation
        setBookmark()
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pathId = try container.decode(String.self, forKey: .pathId)
        self.programPathId = try container.decode(String.self, forKey: .programPathId)
        self.ua = try container.decode(String.self, forKey: .ua)
        self.ckcData = try container.decodeIfPresent(Data.self, forKey: .ckcData)
      self.assetStatus = try container.decodeIfPresent(AssetInfo.RAIAVAssetStatus.self, forKey: .assetStatus)
        if assetStatus == .Downloading {
            // when launch app and previous download session wasnt finished, change to paused
            assetStatus = .Paused
        }
        self.progress = try container.decodeIfPresent(RCTDownloadProgress.self, forKey: .progress)
        self._location = try container.decodeIfPresent(URL.self, forKey: ._location)
        self.bookmarkLocation = try container.decodeIfPresent(Data.self, forKey: .bookmarkLocation)
        self.externalSubtitles = try container.decodeIfPresent([RCTExternalSubtitleModel].self, forKey: .externalSubtitles)
        self.bitrate = try container.decodeIfPresent(Double.self, forKey: .bitrate)
        setBookmark()
    }
    
    public init?(input: NSDictionary) {
        guard let pathId = input["pathId"] as? String else {
            return nil
        }
        guard
            let programInfo = input["programInfo"] as? NSDictionary,
            let programPathId = programInfo["programPathId"] as? String
        else {
            return nil
        }
        guard let ua = input["ua"] as? String else {
            return nil
        }
        
        self.pathId = pathId
        self.programPathId = programPathId
        self.ua = ua
        
        if let url = input["url"] as? String, let location = URL(string: url) {
            self.location = location
        }
        
        if let externalSubtitles = input["externalSubtitles"] as? [NSDictionary] {
            self.externalSubtitles = externalSubtitles.map({ dict in
                return RCTExternalSubtitleModel(dictionary: dict)
            })
        }
    }
    
    private func setBookmark() {
        if assetStatus == .Completed {
            do {
                if bookmarkLocation == nil {
                    bookmarkLocation = try _location?.bookmarkData()
                }
            } catch {
                logger.error("failed to create bookmark with error: \(error)")
            }
        }
    }
    
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
}
