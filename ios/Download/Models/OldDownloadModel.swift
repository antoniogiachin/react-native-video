//
//  OldDownloadModel.swift
//  react-native-video
//
//  Created by Davide Balistreri on 21/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import UIKit

class OldDownloadModel: NSObject, NSCoding {
    public var ua: String
    
    public var identifier: String {
        return (pathId + programPathId + ua).sha1()
    }
    
    public var pathId: String
    
    public var programPathId: String {
        _parentPathId ?? newProgram?.programInfo?.pathID ?? ""
    }
    
    private var _parentPathId: String?
    
    public var ckcData: Data?
    
    public var assetStatus: DownloadState?
    
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
            if assetStatus == .completed {
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
    
    var size: Float?
    var progress: Float? = 0
    var newProgram: OldProgramDetailModel?
    
    public var bitrate: Double?
    
    var isDrm: Bool {
        if newProgram?.rightsmanagement?.diritti?.drm != nil {
            return true
        }
        if newProgram?.programInfo?.rightsManagement?.diritti?.drm != nil {
            return true
        }
        return false
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.ua = ""
        self.pathId = ""
        
        super.init()
        
        // init data for location
        bookmarkLocation = aDecoder.decodeObject(forKey: "bookmarkLocation") as? Data
        _location = aDecoder.decodeObject(forKey: "_location") as? URL
        ckcData = aDecoder.decodeObject(forKey: "ckcData") as? Data
        
        // init status
        let status = aDecoder.decodeInteger(forKey: "assetStatus")
        
        switch status {
        case 2:
            assetStatus = .downloading
        case 3:
            assetStatus = .paused
        case 4:
            assetStatus = .completed
        default:
            assetStatus = .queued
        }
        
        // init metadata
        _parentPathId = aDecoder.decodeObject(forKey: "_parentPathId") as? String ?? ""
        
        //        if let location = location, let json = location.lastPathComponent.split(separator: "_").first?.removingPercentEncoding {
        //            self.pathId = String(json)
        //        }
        
        size = aDecoder.decodeObject(forKey: "size") as? Float
        progress = aDecoder.decodeObject(forKey: "progress") as? Float
        newProgram = aDecoder.decodeObject(forKey: "newProgram") as? OldProgramDetailModel
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

extension OldDownloadModel {
    /// Retrocompatibility with old download system
    static func registerOldClasses() {
        NSKeyedUnarchiver.setClass(OldDownloadModel.self, forClassName: "RaiPlaySwift.DownloadModel")
        NSKeyedUnarchiver.setClass(OldProgramDetailModel.self, forClassName: "RaiPlaySwift.NewProgrammaDetailModel")
        NSKeyedUnarchiver.setClass(OldProgramInfoModel.self, forClassName: "RaiPlaySwift.ProgramInfoModel")
        NSKeyedUnarchiver.setClass(OldRightsManagementModel.self, forClassName: "RaiPlaySwift.RightsManagementModel")
        NSKeyedUnarchiver.setClass(OldDirittiModel.self, forClassName: "RaiPlaySwift.DirittiModel")
        NSKeyedUnarchiver.setClass(OldDRMModel.self, forClassName: "RaiPlaySwift.DRMModel")
    }
}

class OldProgramDetailModel: NSObject, NSCoding {
    var pathID: String?
    var name: String?
    var titoloEpisodio: String?
    var programInfo: OldProgramInfoModel?
    var rightsmanagement: OldRightsManagementModel?
    
    var offlineImage: UIImage?         //episodio
    var offlineImageProgram: UIImage?  //con logo
    
    @objc required init(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObject(forKey: "name") as? String
        pathID = aDecoder.decodeObject(forKey: "pathID") as? String
        titoloEpisodio = aDecoder.decodeObject(forKey: "titoloEpisodio") as? String
        programInfo = aDecoder.decodeObject(forKey: "isPartOf") as? OldProgramInfoModel
        rightsmanagement = aDecoder.decodeObject(forKey: "rights_management") as? OldRightsManagementModel
        offlineImage = aDecoder.decodeObject(forKey: "offlineImage") as? UIImage
        offlineImageProgram = aDecoder.decodeObject(forKey: "offlineImageProgram") as? UIImage
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

class OldRightsManagementModel: NSObject, NSCoding {
    var diritti: OldDirittiModel?
    
    @objc required init(coder aDecoder: NSCoder) {
        diritti = aDecoder.decodeObject(forKey: "diritti") as? OldDirittiModel
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

class OldDirittiModel: NSObject, NSCoding {
    var drm: OldDRMModel?
    
    @objc required init(coder aDecoder: NSCoder) {
        drm = aDecoder.decodeObject(forKey: "drm") as? OldDRMModel
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

class OldDRMModel: NSObject, NSCoding {
    var vod: Bool?
    
    @objc required init(coder aDecoder: NSCoder) {
        vod = aDecoder.decodeObject(forKey: "vod") as? Bool
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

class OldProgramInfoModel: NSObject, NSCoding {
    var pathID : String?
    var name: String?
    var rightsManagement: OldRightsManagementModel?
    
    @objc required init(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObject(forKey: "name") as? String
        pathID = aDecoder.decodeObject(forKey: "pathID") as? String
        rightsManagement = aDecoder.decodeObject(forKey: "rightsManagement") as? OldRightsManagementModel
    }
    
    func encode(with coder: NSCoder) {
        // Encoding not needed
    }
}

// MARK: - Retrocompatibility

extension DownloadModel {
    convenience init(from old: OldDownloadModel) {
        // Size conversion
        let totalBytes = old.size ?? 0
        let bytesDownloaded = totalBytes * (old.progress ?? 0)
        
        // Images conversion
        let videoImage = ImageHelper.shared.saveImage(
            image: old.newProgram?.offlineImage
        )
        let programImage = ImageHelper.shared.saveImage(
            image: old.newProgram?.offlineImageProgram
        )
        
        self.init(
            pathId: old.newProgram?.pathID ?? "",
            ua: old.ua,
            url: "",
            videoInfo: VideoInfoModel(
                templateImg: videoImage ?? "",
                title: old.newProgram?.titoloEpisodio ?? "",
                description: "",
                bytesDownloaded: Int(bytesDownloaded),
                totalBytes: Int(totalBytes),
                id: old.newProgram?.pathID
            ),
            programInfo: ProgramInfoModel(
                templateImg: programImage ?? "",
                title: old.newProgram?.programInfo?.name ?? "",
                description: "",
                programPathId: old.newProgram?.programInfo?.pathID
            ),
            state: old.assetStatus,
            _ckcData: old.ckcData,
            _bitrate: old.bitrate,
            _location: old._location,
            _bookmarkLocation: old.bookmarkLocation
        )
    }
}
