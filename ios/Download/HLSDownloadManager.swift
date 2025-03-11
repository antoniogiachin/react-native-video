//
//  HLSDownloadManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

class HLSDownloadManager {
    static let shared = HLSDownloadManager()
    
    var downloads: [NewDownloadModel] = [] {
        didSet {
            saveDownloads()
        }
    }
    
    private let assetDownloader = AssetDownloader()
    
    private init() {
        downloads.append(contentsOf: DownloadMetadataCacheManager.shared.get())
        assetDownloader.delegate = self
    }
    
    func resume(
        _ download: NewDownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) {
        guard let url = URL(string: download.url) else {
            // Invalid URL
            notifyError(
                error: NSError(
                    domain: "HLSDownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
                ),
                download: download
            )
            return
        }
        
        if downloads.firstIndex(of: download) == nil {
            // Starting a new download
            RCTExternalSubtitlesCacheManager.shared.downloadSubtitles(
                videoId: download.identifier,
                subtitles: download.subtitles
            ) { [weak self] subtitles, error in
                guard let self else { return }
                if let error {
                    notifyError(error: error, download: download)
                    return
                }
                
                downloads.append(download)
                resume(download, licenseData: licenseData)
            }
        } else {
            // Resuming or proceeding with a download
            let asset = AVURLAsset(url: url)
            assetDownloader.resume(
                assetInfo: AssetInfo(
                    identifier: download.identifier,
                    avUrlAsset: asset,
                    licenseData: nil,
                    bitrate: nil  // download.bitrate
                )
            )
        }
    }
  
  func renew(download: DownloadModel, licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) {
      if let location = download.location {
          let avUrlAsset = AVURLAsset(url: location)
        self.assetDownloader.renew(assetInfo: AssetInfo(identifier: download.identifier, avUrlAsset: avUrlAsset, licenseData: licenseData)) { [weak self] result in
              guard let self else { return }
              switch result {
              case .failure(let error):
                  self.notifyRenewLicense(download: download, result: false)
                  logger.debug("license renewed failed \(error)")
              case .success(_):
                  self.notifyRenewLicense(download: download, result: true)
                  logger.debug("license renewed")
              }
          }
      }
  }
  
  func pause(_ download: NewDownloadModel) {
      if let identifier = get(download)?.identifier {
          assetDownloader.cancelDownloadOfAsset(identifier: identifier)
      }
  }
  
    func get(_ download: NewDownloadModel) -> NewDownloadModel? {
        return downloads.first(where: { model in
            model.identifier == download.identifier
        })
    }
  
  func getDownload(assetInfo: AssetInfo) -> NewDownloadModel? {
      return downloads.first(where: { model in
          model.identifier == assetInfo.identifier
      })
  }
  
  func delete(_ download: NewDownloadModel) {
      
      if let download = get(download) {
          
          assetDownloader.cancelDownloadOfAsset(identifier: download.identifier)
          
//          if let url = download.location {
//              do {
//                  //RIMOZIONE BOOKMARK HLS
//                  try FileManager.default.removeItem(at: url)
//              } catch {
//                  logger.debug(error.localizedDescription)
//              }
//          }
          
          let supportFiles = "\(DownloadMetadataCacheManager.MEDIA_CACHE_KEY)/\(download.identifier)"
          
          if let url = URL(string: supportFiles) {
              do {
                  //RIMOZIONE BOOKMARK HLS
                  try FileManager.default.removeItem(at: url)
              } catch {
                  logger.debug(error.localizedDescription)
              }
          }
      }
      
      downloads.removeAll(where: { model in
          model.identifier == download.identifier
      })
  }
  
    func notifyError(error: Error, download: NewDownloadModel) {
        DownloadManagerModule.sendEvent(
            .onDownloadError,
            body: DownloadError(
                with: download,
                msg: error.localizedDescription
            )
        )
    }
  
    private func updateDownloads(
        assetInfo: AssetInfo,
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
  
    func saveDownloads() {
        DownloadMetadataCacheManager.shared.save(downloads)
    }
    
    func notifyDownloadsProgress() {
        let body = downloads.map { model in
            return model.toDictionary()
        }
        DownloadManagerModule.sendEvent(
            .onDownloadProgress,
            body: body
        )
    }
    
    func notifyDownloadsChanged() {
        let body = downloads.map { model in
            return model.toDictionary()
        }
        DownloadManagerModule.sendEvent(
            .onDownloadListChanged,
            body: body
        )
    }
  
  func notifyRenewLicense(download: DownloadModel, result: Bool) {
      let payload = RenewLicensePayload(item: RCTDownloadItem(model: download), result: result)
      DownloadManagerModule.sendEvent(
        .onDownloadListChanged,
        body: payload.toDictionary() ?? [:]
      )
  }
}

extension HLSDownloadManager: AssetDownloaderDelegate {
    func downloadStateChanged(assetInfo: AssetInfo, state: DownloadState) {
        updateDownloads(assetInfo: assetInfo, state: state)
        notifyDownloadsChanged()
    }
    
    func downloadProgress(assetInfo: AssetInfo, percentage: Double, loaded: Double, total: Double) {
        updateDownloads(assetInfo: assetInfo, loaded: loaded, total: total)
        notifyDownloadsProgress()
    }
    
    func downloadError(assetInfo: AssetInfo, error: Error) {
        if let download = getDownload(assetInfo: assetInfo) {
            notifyError(error: error, download: download)
            delete(download)
        }
    }
    
    func downloadLocationAvailable(assetInfo: AssetInfo, location: URL) {
        updateDownloads(assetInfo: assetInfo, location: location)
    }
    
    func downloadCkcAvailable(assetInfo: AssetInfo, ckc: Data) {
        updateDownloads(assetInfo: assetInfo, ckcData: ckc)
    }
}
