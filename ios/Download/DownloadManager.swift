//
//  DownloadManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation
import AVFoundation

class DownloadManager: NSObject, DownloadLogging {
    static let shared = DownloadManager()
    
    /// List of all downloaded and downloading items.
    private(set) var downloads: [DownloadModel] = []
    
    /// List of simultaneous downloads. It will be cleared once all downloads are completed.
    private var downloading: [DownloadModel] = []
    
    private let downloader = AssetDownloader()
    
    private override init() {
        super.init()
        
        // Retrocompatibility with old download system
        OldDownloadModel.registerOldClasses()
        
        let downloads = fetchDownloads()
        
        // Updating previous unfinished download sessions when launching the app
        for download in downloads {
            if download.state == .downloading {
                download.state = .paused
            }
        }
        self.downloads = downloads
        downloader.delegate = self
        
        // Updating active download list
        downloading = downloads.filter { $0.state == .paused }
        if downloading.isNotEmpty {
            notifyDownloadingProgress()
        }
    }
    
    func resume(
        _ download: DownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) {
        log(debug: "Resume download: \(download)")
        
        guard let url = URL(string: download.url) else {
            // Invalid URL
            log(error: "Invalid download URL: \(download)")
            
            notifyError(
                NSError(
                    domain: "HLSDownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
                ),
                for: download
            )
            return
        }
        
        guard download.state != .downloading else {
            // Already downloading
            log(info: "Already downloading \(download)")
            return
        }
        
        if downloads.firstIndex(of: download) == nil {
            // Starting a new download
            log(info: "Starting a new download: \(download)")
            
            downloadSubtitles(
                videoId: download.identifier,
                subtitles: download.subtitles
            ) { [weak self] subtitles, error in
                guard let self else { return }
                
                if let error {
                    notifyError(error, for: download)
                    return
                }
                
                download.state = .downloading
                
                // The same object is referenced in both downloads and downloading lists
                downloads.append(download)
                downloading.append(download)
                
                // Proceeding with the download
                let asset = AVURLAsset(url: url)
                downloader.resume(DownloadAssetTaskModel(
                    identifier: download.identifier,
                    asset: asset,
                    licenseData: licenseData
                ))
            }
        } else {
            // Resuming a download
            log(info: "Resuming a download: \(download)")
            download.state = .downloading
            
            let asset = AVURLAsset(url: download.location ?? url)
            downloader.resume(DownloadAssetTaskModel(
                identifier: download.identifier,
                asset: asset,
                licenseData: licenseData,
                bitrate: download._bitrate
            ))
        }
    }
    
    func renew(
        _ download: DownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?
    ) {
        log(debug: "Renew download: \(download)")
        
        if let location = download.location {
            let avUrlAsset = AVURLAsset(url: location)
            downloader.renew(DownloadAssetTaskModel(
                identifier: download.identifier,
                asset: avUrlAsset,
                licenseData: licenseData
            )) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    notifyRenewLicense(download: download, result: false)
                    log(error: "License renew failed for \(download): \(error.localizedDescription)")
                case .success(_):
                    notifyRenewLicense(download: download, result: true)
                    log(info: "License renewed: \(download)")
                }
            }
        }
    }
    
    func pause(_ download: DownloadModel) {
        log(info: "Pausing download: \(download)")
        
        guard let download = get(download) else {
            // Item not found
            log(debug: "Pause download not found: \(download)")
            return
        }
        
        downloader.cancel(identifier: download.identifier)
        download.state = .paused
        saveDownloads()
        
        notifyDownloadingProgress()
        notifyDownloadsChanged()
    }
    
    private func get(_ download: DownloadModel) -> DownloadModel? {
        downloads.first(where: { $0 == download })
    }
    
    private func get(from: DownloadAssetTaskModel) -> DownloadModel? {
        downloads.first(where: { $0.identifier == from.identifier })
    }
    
    func delete(_ download: DownloadModel) {
        log(verbose: "Deleting download: \(download)")
        
        guard let download = get(download) else {
            // Item not found
            log(debug: "Delete download not found: \(download)")
            return
        }
        
        downloader.cancel(identifier: download.identifier)
        
        if let url = download.location {
            do {
                try FileManager.default.removeItem(at: url)
                log(info: "Download files deleted: \(url)")
            } catch {
                log(error: "Delete download files at url (\(url)) error: \(error.localizedDescription)")
            }
        }
        
        let supportFiles = "\(DownloadManager.MEDIA_CACHE_KEY)/\(download.identifier)"
        
        if let url = URL(string: supportFiles) {
            do {
                try FileManager.default.removeItem(at: url)
                log(debug: "Download supporting files deleted: \(url)")
            } catch {
                log(debug: "Delete supporting download files at url (\(url)) error: \(error.localizedDescription)")
            }
        }
        
        log(verbose: "Removing download from lists: \(download)")
        downloads.remove { $0 == download }
        downloading.remove { $0 == download }
        
        notifyDownloadsChanged()
        saveDownloads()
    }
    
    func notifyError(_ error: Error, for download: DownloadModel) {
        DownloadManagerModule.sendEvent(
            .onDownloadError,
            body: DownloadError(
                with: download,
                msg: error.localizedDescription
            )
        )
    }
    
    private func update(
        _ download: DownloadModel,
        with info: DownloadAssetTaskModel,
        state: DownloadState? = nil,
        loaded: Int? = nil,
        total: Int? = nil,
        location: URL? = nil,
        ckcData: Data? = nil
    ) {
        if let state {
            download.state = state
        }
        if let loaded {
            download.videoInfo.bytesDownloaded = loaded
        }
        if let total {
            download.videoInfo.totalBytes = total
        }
        if let location {
            download.location = location
        }
        if let ckcData {
            download._ckcData = ckcData
        }
        if let bitrate = info.bitrate {
            download._bitrate = bitrate
        }
    }
    
    func notifyDownloadingProgress() {
        log(verbose: "Notifying downloading progress")
        
        let body = downloading.map { $0.toDictionary() }
        DownloadManagerModule.sendEvent(
            .onDownloadProgress,
            body: body
        )
    }
    
    func notifyDownloadsChanged() {
        log(verbose: "Notifying downloads changed")
        
        let body = downloads.map { $0.toDictionary() }
        DownloadManagerModule.sendEvent(
            .onDownloadListChanged,
            body: body
        )
    }
    
    func notifyRenewLicense(download: DownloadModel, result: Bool) {
        // let payload = RenewLicensePayload(item: RCTDownloadItem(model: download), result: result)
        // DownloadManagerModule.sendEvent(
        //     .onDownloadListChanged,
        //     body: payload.toDictionary() ?? [:]
        // )
    }
    
    // MARK: - Media
    
    private static let MEDIA_CACHE_KEY = "media_cache"
    private static let OLD_MEDIA_KEY = "downloadingKey"
    
    /// Used to migrate old downloads to the new system.
    private func getOldDownloads() -> [DownloadModel]? {
        guard let oldDownloads = UserDefaults.standard.dictionary(
            forKey: DownloadManager.OLD_MEDIA_KEY
        ) else {
            log(verbose: "No old downloads found")
            return nil
        }
        
        let allDownloads = oldDownloads.compactMap { (key, value) -> [DownloadModel]? in
            guard key.isValidEmail, let array = value as? [Data] else {
                log(verbose: "Found an invalid old download")
                return nil
            }
            
            return array.compactMap { data -> DownloadModel? in
                do {
                    if let old = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
                        data
                    ) as? OldDownloadModel, old.location != nil {
                        let download = DownloadModel(from: old)
                        download.ua = key
                        return download
                    } else {
                        log(error: "Found an invalid old download without location")
                        return nil
                    }
                } catch {
                    log(error: "Something went wrong while recovering an old download: \(error)")
                    return nil
                }
            }
        }
        
        let downloads = allDownloads.flatMap { $0 }
        
        if !downloads.isEmpty {
            // UserDefaults.standard.removeObject(forKey: DownloadManager.OLD_MEDIA_KEY)
            // debugPrint("REMOVED OLD MEDIA")
        }
        
        return downloads.isEmpty ? nil : downloads
    }
    
    func fetchDownloads() -> [DownloadModel] {
        var downloads: [DownloadModel] = []
        if let oldDownloads = getOldDownloads() {
            downloads.append(contentsOf: oldDownloads)
        }
        if let newDownloads = UserDefaults.standard.getDownloads() {
            downloads.append(contentsOf: newDownloads)
        }
        return downloads
    }
    
    /// Use this to persist download info in UserDefaults.
    private func saveDownloads() {
        UserDefaults.standard.setDownloads(downloads)
    }
    
    static func cacheDirectoryPath() -> URL {
        let cachePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cachePath)
    }
    
    static func createDirectoryIfNotExists(
        withName name: String
    ) -> (url: URL?, error: Error?) {
        let directoryUrl = cacheDirectoryPath().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: directoryUrl.path) {
            return (directoryUrl, nil)
        }
        do {
            try FileManager.default.createDirectory(
                at: directoryUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return (directoryUrl, nil)
        } catch  {
            return (nil, error)
        }
    }
    
    // MARK: - Subtitles
    
    private static let SUBTITLES_PATH = "subtitles"
    
    func downloadSubtitles(
        videoId: String,
        subtitles: [DownloadSubtitlesModel]?,
        completion: @escaping (_ subtitles: [DownloadSubtitlesModel]?, _ err: Error?) -> Void
    ) {
        guard let subtitles else {
            completion(nil, nil)
            return
        }
        
        var cachedSubtitles: [DownloadSubtitlesModel] = []
        var localError: Error?
        let group = DispatchGroup()
        subtitles.forEach { subtitle in
            group.enter()
            if let url = URL(string: subtitle.webUrl) {
                let subtitleId = subtitle.language
                downloadData(url: url) { data, error in
                    if let error {
                        localError = error
                        group.leave()
                        return
                    }
                    let diskUrl = DownloadManager.createDirectoryIfNotExists(
                        withName: "\(DownloadManager.MEDIA_CACHE_KEY)/\(videoId)/\(DownloadManager.SUBTITLES_PATH)/\(subtitleId)"
                    )
                    if let error = diskUrl.error {
                        localError = error
                        group.leave()
                        return
                    }
                    let updatedSubtitle = DownloadSubtitlesModel(
                        language: subtitle.language,
                        webUrl: subtitle.webUrl,
                        localUrl: diskUrl.url?.absoluteString
                    )
                    cachedSubtitles.append(updatedSubtitle)
                    group.leave()
                }
            } else {
                localError = NSError(domain: "url or subtitle id not valid", code: 500)
                group.leave()
            }
        }
        if let localError {
            group.notify(queue: .main, execute: {
                completion(nil, localError)
            })
            return
        }
        group.notify(queue: .main, execute: {
            completion(cachedSubtitles, nil)
        })
    }
    
    private func downloadData(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        NetworkRequest(
            url: url.absoluteString
        ).responseData { result in
            switch result {
            case .success(let data):
                completion(data, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    /// Clear downloading list if no simultaneous downloads are in progress.
    private func clearDownloadingIfNeeded() {
        if downloading.contains(where: { $0.state == .downloading }) == false {
            downloading.removeAll()
        }
    }
}

extension DownloadManager: AssetDownloaderDelegate {
    func downloadStateChanged(_ info: DownloadAssetTaskModel, state: DownloadState) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, state: state)
        saveDownloads()
        
        clearDownloadingIfNeeded()
        notifyDownloadsChanged()
        notifyDownloadingProgress()
    }
    
    func downloadProgress(_ info: DownloadAssetTaskModel, loaded: Int, total: Int) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, loaded: loaded, total: total)
        notifyDownloadingProgress()
    }
    
    func downloadError(_ info: DownloadAssetTaskModel, error: Error) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        notifyError(error, for: download)
        delete(download)
        saveDownloads()
        notifyDownloadingProgress()
    }
    
    func downloadLocationAvailable(_ info: DownloadAssetTaskModel, location: URL) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, location: location)
        saveDownloads()
    }
    
    func downloadCkcAvailable(_ info: DownloadAssetTaskModel, ckc: Data) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, ckcData: ckc)
    }
}
