//
//  DownloadMetadataCacheManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

class DownloadMetadataCacheManager {
    
    static let shared = DownloadMetadataCacheManager()
    static let MEDIA_CACHE_KEY = "media_cache"
    
    private let OLD_MEDIA_KEY = "downloadingKey"
    private static let MEDIA_CACHE_KEY_DEFAULTS = Bundle.main.bundleIdentifier! + "_" + DownloadMetadataCacheManager.MEDIA_CACHE_KEY
    private let defaults = UserDefaults.standard
    
    private func isValidEmail(_ key: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$", options: .caseInsensitive)
            return regex.firstMatch(in: key, options: [], range: NSRange(location: 0, length: key.count)) != nil
        } catch let error {
            logger.error("\(error)")
            return false
        }
    }
    
    private init() {
        NSKeyedUnarchiver.setClass(OldDownloadModel.self, forClassName: "RaiPlaySwift.DownloadModel")
    }
    
    private func getOldDownloads() -> [DownloadModel]? {
        
        let downloads = defaults.dictionary(forKey: OLD_MEDIA_KEY)?.compactMap ({ k, v -> [DownloadModel]? in
            if isValidEmail(k) {
                let arrayOfData = v as? [Data]
                let oldDownloads = arrayOfData?.compactMap({ elem -> DownloadModel? in
                    do {
                        if let model = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(elem) as? OldDownloadModel, let _ = model.location {
                            model.ua = k
                            return DownloadModel(old: model)
                        }
                        logger.error("something went wrong during recover old downloads")
                        return nil
                    } catch let error {
                        logger.error("\(error)")
                        return nil
                    }
                })
                return oldDownloads
            }
            return nil
        })
        
        if let downloads, !downloads.isEmpty {
            //defaults.removeObject(forKey: OLD_MEDIA_KEY)
            //logger.debug("REMOVED OLD MEDIA")
        }
        
        return downloads?.reduce([], +)
    }
    
    func get() -> [NewDownloadModel] {
        var downloads: [NewDownloadModel] = []
//        if let oldDownloads = getOldDownloads() {
//            downloads.append(contentsOf: oldDownloads)
//        }
        if let newDownloads = UserDefaults.standard.getDownloads() {
            downloads.append(contentsOf: newDownloads)
        }
        return downloads
    }
    
    func save(_ downloads: [NewDownloadModel]) {
        UserDefaults.standard.setDownloads(downloads)
    }
    
    static func cacheDirectoryPath() -> URL {
        let cachePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cachePath)
    }
    
    static func createDirectoryIfNotExists(
        withName name: String
    ) -> (url: URL?, error: Error?) {
        let directoryUrl = self.cacheDirectoryPath().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: directoryUrl.path) {
            return (directoryUrl, nil)
        }
        do {
            try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
            return (directoryUrl, nil)
        } catch  {
            return (nil, error)
        }
    }
}
