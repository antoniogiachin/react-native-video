//
//  DownloadManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    /// List of all downloaded and downloading items.
    private(set) var downloads: [DownloadModel] = [] {
        didSet {
            saveDownloads()
        }
    }
    
    /// List of simultaneous downloads. It will be cleared once all downloads are completed.
    private var downloading: [DownloadModel] = []
    
    private let downloader = AssetDownloader()
    
    private override init() {
        super.init()
        
        NSKeyedUnarchiver.setClass(OldDownloadModel.self, forClassName: "RaiPlaySwift.DownloadModel")
        
        let downloads = fetchDownloads()
        
        // Updating previous unfinished download sessions when launching the app
        for download in downloads {
            if download.state == .downloading {
                download.state = .paused
                downloading.append(download)
            }
        }
        self.downloads = downloads
        downloader.delegate = self
        
        if downloading.isEmpty == false {
            notifyDownloadingProgress()
        }
    }
    
    func resume(
        _ download: DownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) {
        guard let url = URL(string: download.url) else {
            // Invalid URL
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
        
        if downloads.firstIndex(of: download) == nil {
            // Starting a new download
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
                downloader.resume(DownloadInfo(
                    identifier: download.identifier,
                    asset: asset,
                    licenseData: licenseData
                ))
            }
        } else {
            // Resuming a download
            download.state = .downloading
            
            let asset = AVURLAsset(url: download.location ?? url)
            downloader.resume(DownloadInfo(
                identifier: download.identifier,
                asset: asset,
                licenseData: licenseData,
                bitrate: download._bitrate
            ))
        }
    }
    
    func renew(_ download: DownloadModel, licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) {
        if let location = download.location {
            let avUrlAsset = AVURLAsset(url: location)
            downloader.renew(DownloadInfo(
                identifier: download.identifier,
                asset: avUrlAsset,
                licenseData: licenseData
            )) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    notifyRenewLicense(download: download, result: false)
                    debugPrint("license renewed failed \(error)")
                case .success(_):
                    notifyRenewLicense(download: download, result: true)
                    debugPrint("license renewed")
                }
            }
        }
    }
    
    func pause(_ download: DownloadModel) {
        guard let download = get(download) else {
            // Item not found
            return
        }
        
        downloader.cancel(identifier: download.identifier)
        download.state = .paused
        saveDownloads()
        
        notifyDownloadingProgress()
        notifyDownloadsChanged()
    }
    
    private func get(_ download: DownloadModel) -> DownloadModel? {
        downloads.first(where: { $0.identifier == download.identifier })
    }
    
    private func get(from: DownloadInfo) -> DownloadModel? {
        downloads.first(where: { $0.identifier == from.identifier })
    }
    
    func delete(_ download: DownloadModel) {
        guard let download = get(download) else {
            // Item not found
            return
        }
        
        downloader.cancel(identifier: download.identifier)
        
        if let url = download.location {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        
        let supportFiles = "\(DownloadManager.MEDIA_CACHE_KEY)/\(download.identifier)"
        
        if let url = URL(string: supportFiles) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        
        downloads.removeAll(where: { model in
            model.identifier == download.identifier
        })
        
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
        with info: DownloadInfo,
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
        let body = downloading.map { $0.toDictionary() }
        DownloadManagerModule.sendEvent(
            .onDownloadProgress,
            body: body
        )
    }
    
    func notifyDownloadsChanged() {
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
    private static let MEDIA_CACHE_KEY_DEFAULTS = Bundle.main.bundleIdentifier! + "_" + MEDIA_CACHE_KEY
    
    private func getOldDownloads() -> [DownloadModel]? {
        let downloads = UserDefaults.standard.dictionary(
            forKey: DownloadManager.OLD_MEDIA_KEY
        )?.compactMap ({ k, v -> [DownloadModel]? in
            if k.isValidEmail {
                let arrayOfData = v as? [Data]
                let oldDownloads = arrayOfData?.compactMap({ elem -> DownloadModel? in
                    do {
                        if let model = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(elem) as? OldDownloadModel, let _ = model.location {
                            model.ua = k
                            // FIXME: return DownloadModel(old: model)
                            return nil
                        }
                        debugPrint("something went wrong during recover old downloads")
                        return nil
                    } catch let error {
                        debugPrint("\(error)")
                        return nil
                    }
                })
                return oldDownloads
            }
            return nil
        })
        
        if let downloads, !downloads.isEmpty {
            //defaults.removeObject(forKey: OLD_MEDIA_KEY)
            //debugPrint("REMOVED OLD MEDIA")
        }
        
        return downloads?.reduce([], +)
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
    func downloadStateChanged(_ info: DownloadInfo, state: DownloadState) {
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
    
    func downloadProgress(_ info: DownloadInfo, loaded: Int, total: Int) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, loaded: loaded, total: total)
        notifyDownloadingProgress()
    }
    
    func downloadError(_ info: DownloadInfo, error: Error) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        notifyError(error, for: download)
        delete(download)
        saveDownloads()
    }
    
    func downloadLocationAvailable(_ info: DownloadInfo, location: URL) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, location: location)
        saveDownloads()
    }
    
    func downloadCkcAvailable(_ info: DownloadInfo, ckc: Data) {
        guard let download = get(from: info) else {
            // Item not found
            return
        }
        
        update(download, with: info, ckcData: ckc)
    }
}
