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
    private var _downloads: [DownloadModel] = []
    /// Thread-safe lock for downloads list.
    private let downloadsLock = NSLock()
    
    /// List of simultaneous downloads. It will be cleared once all downloads are completed.
    private var _downloading: [DownloadModel] = []
    /// Thread-safe lock for downloading list.
    private let downloadingLock = NSLock()
    
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
        setDownloads(downloads)
        
        // Updating downloads status and saving eventually migrated downloads
        saveDownloads()
        
        // Updating active download list
        let downloading = downloads.filter { $0.state == .paused }
        setDownloading(downloading)
        if downloading.isNotEmpty {
            notifyDownloadingProgress()
        }
        
        downloader.delegate = self
    }
    
    func resume(
        _ download: DownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) {
        Task {
            do {
                try await asyncResume(download, licenseData: licenseData)
            } catch {
                notifyError(error, for: download)
            }
        }
    }
    
    private func asyncResume(
        _ download: DownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) async throws {
        log(debug: "Resume download: \(download)")
        
        guard let url = URL(string: download.url) else {
            // Invalid URL
            log(error: "Invalid download URL (\(download)): \(download.url)")
            
            throw NSError(
                domain: "HLSDownloadManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        guard download.state != .downloading else {
            // Already downloading
            log(info: "Already downloading \(download)")
            return
        }
        
        if getDownloads().firstIndex(of: download) == nil {
            // Starting a new download
            log(info: "Starting a new download: \(download)")
            
            // The same object is referenced in both downloads and downloading lists
            download.state = .downloading
            addDownload(download)
            addDownloading(download)
            notifyDownloadingProgress()
            
            // Downloading subtitles
            log(debug: "Downloading subtitles: \(download)")
            let updatedSubtitles = await downloadSubtitles(
                videoId: download.identifier,
                subtitles: download.subtitles
            )
            download.subtitles = updatedSubtitles
            
            // Downloading thumbnails
            log(debug: "Downloading thumbnails: \(download)")
            if let thumbnail = await ImageHelper.shared.downloadAndSave(
                from: download.videoInfo.templateImg,
                in: download.identifier
            ) {
                log(verbose: "Thumbnail downloaded and saved: \(thumbnail)")
                download.videoInfo.templateImg = thumbnail
            }
            
            if let thumbnail = await ImageHelper.shared.downloadAndSave(
                from: download.programInfo?.templateImg,
                in: download.identifier
            ) {
                log(verbose: "Thumbnail downloaded and saved: \(thumbnail)")
                download.programInfo?.templateImg = thumbnail
            }
            
            // Proceeding with asset files download
            log(debug: "Proceeding with asset files download: \(download)")
            let asset = AVURLAsset(url: url)
            downloader.resume(DownloadAssetTaskModel(
                identifier: download.identifier,
                asset: asset,
                licenseData: licenseData
            ))
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
        getDownloads().first(where: { $0 == download })
    }
    
    private func get(from: DownloadAssetTaskModel) -> DownloadModel? {
        getDownloads().first(where: { $0.identifier == from.identifier })
    }
    
    func delete(_ download: DownloadModel, notify: Bool = true) {
        log(verbose: "Deleting download: \(download)")
        
        guard let download = get(download) else {
            // Item not found
            log(debug: "Delete download not found: \(download)")
            return
        }
        
        downloader.cancel(identifier: download.identifier)
        
        do {
            try FileHelper.shared.delete(download)
            log(info: "Download files deleted: \(download)")
        } catch {
            log(error: "Error while deleting download files: \(error.localizedDescription)")
        }
        
        log(verbose: "Removing download from lists: \(download)")
        removeDownload(download)
        removeDownloading(download)
        
        if notify {
            notifyDownloadsChanged()
            saveDownloads()
        }
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
        
        let body = getDownloading().map { $0.toDictionary() }
        DownloadManagerModule.sendEvent(
            .onDownloadProgress,
            body: body
        )
    }
    
    func notifyDownloadsChanged() {
        log(verbose: "Notifying downloads changed")
        
        let body = getDownloads().map { $0.toDictionary() }
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
        UserDefaults.standard.setDownloads(getDownloads())
    }
    
    /// Clear downloading list if no simultaneous downloads are in progress.
    private func clearDownloadingIfNeeded() {
        if getDownloading().contains(where: { $0.state == .downloading }) == false {
            removeAllDownloading()
        }
    }
    
    // MARK: - Migration
    
    private static let OLD_MEDIA_KEY = "downloadingKey"
    
    /// Used to migrate old downloads to the new system.
    private func getOldDownloads() -> [DownloadModel]? {
        guard let oldDownloads = UserDefaults.standard.dictionary(
            forKey: DownloadManager.OLD_MEDIA_KEY
        ) else {
            log(verbose: "No old downloads found")
            return nil
        }
        
        let migrated = oldDownloads.compactMap { (key, value) -> [DownloadModel]? in
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
        }.flatMap { $0 }
        
        if migrated.isNotEmpty {
            UserDefaults.standard.removeObject(forKey: DownloadManager.OLD_MEDIA_KEY)
            log(info: "Old downloads migrated and removed")
        }
        
        return migrated.isNotEmpty ? migrated : nil
    }
    
    // MARK: - Subtitles
    
    func downloadSubtitles(
        videoId: String,
        subtitles: [SubtitleModel]?
    ) async -> [SubtitleModel] {
        var updatedSubtitles: [SubtitleModel] = []
        
        for subtitle in subtitles ?? [] {
            do {
                let url = try await SubtitleHelper.shared.downloadAndSave(
                    from: subtitle.webUrl,
                    in: videoId,
                    fileName: subtitle.language
                )
                log(verbose: "Subtitle downloaded and saved: \(subtitle.language)")
                
                updatedSubtitles.append(SubtitleModel(
                    language: subtitle.language,
                    webUrl: subtitle.webUrl,
                    localUrl: url
                ))
            } catch {
                log(error: "Error while downloading subtitle (\(subtitle.language)): \(error)")
            }
        }
        
        return updatedSubtitles
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
        delete(download, notify: false)
        saveDownloads()
        notifyDownloadsChanged()
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

// MARK: - Thread-safe access to downloads

extension DownloadManager {
    func addDownload(_ download: DownloadModel) {
        downloadsLock.withLock {
            _downloads.append(download)
        }
    }
    
    func removeDownload(_ download: DownloadModel) {
        downloadsLock.withLock {
            _downloads.remove { $0 == download }
        }
    }
    
    func setDownloads(_ downloads: [DownloadModel]) {
        downloadsLock.withLock {
            _downloads = downloads
        }
    }
    
    func getDownloads() -> [DownloadModel] {
        downloadsLock.lock()
        let copy = _downloads
        downloadsLock.unlock()
        return copy
    }
    
    func addDownloading(_ download: DownloadModel) {
        downloadingLock.withLock {
            _downloading.append(download)
        }
    }
    
    func removeDownloading(_ download: DownloadModel) {
        downloadingLock.withLock {
            _downloading.remove { $0 == download }
        }
    }
    
    func removeAllDownloading() {
        downloadingLock.withLock {
            _downloading.removeAll()
        }
    }
    
    func getDownloading() -> [DownloadModel] {
        downloadingLock.lock()
        let copy = _downloading
        downloadingLock.unlock()
        return copy
    }
    
    func setDownloading(_ downloading: [DownloadModel]) {
        downloadingLock.withLock {
            _downloading = downloading
        }
    }
}
