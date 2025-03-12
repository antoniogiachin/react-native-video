//
//  DownloadManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

class DownloadManager {
    static let shared = DownloadManager()
    
    /// List of all downloaded and downloading items.
    var downloads: [DownloadModel] = [] {
        didSet {
            saveDownloads(downloads)
        }
    }
    
    /// List of currently downloading items. It will be cleared after all downloads are completed.
    var downloading: [DownloadModel] = []
    
    private let downloader = AssetDownloader()
    
    private init() {
        NSKeyedUnarchiver.setClass(OldDownloadModel.self, forClassName: "RaiPlaySwift.DownloadModel")
        
        let downloads = fetchDownloads()
        // Updating previous unfinished download sessions when launching the app
        for download in downloads {
            if download.state == .downloading {
                download.state = .paused
            }
        }
        self.downloads = downloads
        downloader.delegate = self
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
                
                downloads.append(download)
                resume(download, licenseData: licenseData)
            }
        } else {
            // Resuming or proceeding with a download
            let asset = AVURLAsset(url: url)
            downloader.resume(
                assetInfo: DownloadInfo(
                    identifier: download.identifier,
                    avUrlAsset: asset,
                    licenseData: nil,
                    bitrate: nil  // download.bitrate
                )
            )
        }
    }
  
  func renew(_ download: DownloadModel, licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) {
      if let location = download.location {
          let avUrlAsset = AVURLAsset(url: location)
        self.downloader.renew(assetInfo: DownloadInfo(identifier: download.identifier, avUrlAsset: avUrlAsset, licenseData: licenseData)) { [weak self] result in
              guard let self else { return }
              switch result {
              case .failure(let error):
                  self.notifyRenewLicense(download: download, result: false)
                  debugPrint("license renewed failed \(error)")
              case .success(_):
                  self.notifyRenewLicense(download: download, result: true)
                  debugPrint("license renewed")
              }
          }
      }
  }
  
  func pause(_ download: DownloadModel) {
      if let identifier = get(download)?.identifier {
          downloader.cancelDownloadOfAsset(identifier: identifier)
      }
  }
  
    func get(_ download: DownloadModel) -> DownloadModel? {
        return downloads.first(where: { model in
            model.identifier == download.identifier
        })
    }
    
    private func getDownload(from: DownloadInfo) -> DownloadModel? {
        return downloads.first(where: { $0.identifier == from.identifier })
    }
    
    func delete(_ download: DownloadModel) {
        
      if let download = get(download) {
          
          downloader.cancelDownloadOfAsset(identifier: download.identifier)
          
//          if let url = download.location {
//              do {
//                  //RIMOZIONE BOOKMARK HLS
//                  try FileManager.default.removeItem(at: url)
//              } catch {
//                  debugPrint(error.localizedDescription)
//              }
//          }
          
          let supportFiles = "\(DownloadManager.MEDIA_CACHE_KEY)/\(download.identifier)"
          
          if let url = URL(string: supportFiles) {
              do {
                  //RIMOZIONE BOOKMARK HLS
                  try FileManager.default.removeItem(at: url)
              } catch {
                  debugPrint(error.localizedDescription)
              }
          }
      }
      
      downloads.removeAll(where: { model in
          model.identifier == download.identifier
      })
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
  
    private func updateDownloads(
        assetInfo: DownloadInfo,
        state: DownloadState? = nil,
        loaded: Double? = nil,
        total: Double? = nil,
        location: URL? = nil,
        ckcData: Data? = nil
    ) {
        downloads.modifyForEach { index, element in
            if element.identifier == assetInfo.identifier {
                if let state {
                    element.state = state
                }
                if let loaded {
                    element.videoInfo.bytesDownloaded = Int(loaded)
                    element.programInfo?.bytesDownloaded = Int(loaded)
                }
                if let total {
                    element.videoInfo.totalBytes = Int(total)
                    element.programInfo?.totalBytes = Int(total)
                }
                // if let location = location {
                //     element.location = location
                // }
                // if let ckcData = ckcData {
                //     element.ckcData = ckcData
                // }
                // if let bitrate = assetInfo.bitrate {
                //     element.bitrate = bitrate
                // }
            }
        }
    }
  
    func notifyDownloadsProgress() {
        let body = downloads.map { $0.toDictionary() }
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
    
    func saveDownloads(_ downloads: [DownloadModel]) {
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
}

extension DownloadManager: AssetDownloaderDelegate {
    func downloadStateChanged(assetInfo: DownloadInfo, state: DownloadState) {
        updateDownloads(assetInfo: assetInfo, state: state)
        notifyDownloadsChanged()
    }
    
    func downloadProgress(assetInfo: DownloadInfo, percentage: Double, loaded: Double, total: Double) {
        updateDownloads(assetInfo: assetInfo, loaded: loaded, total: total)
        notifyDownloadsProgress()
    }
    
    func downloadError(assetInfo: DownloadInfo, error: Error) {
        if let download = getDownload(from: assetInfo) {
            notifyError(error, for: download)
            delete(download)
        }
    }
    
    func downloadLocationAvailable(assetInfo: DownloadInfo, location: URL) {
        updateDownloads(assetInfo: assetInfo, location: location)
    }
    
    func downloadCkcAvailable(assetInfo: DownloadInfo, ckc: Data) {
        updateDownloads(assetInfo: assetInfo, ckcData: ckc)
    }
}
