//
//  HLSDownloadManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

public class HLSDownloadManager {
  
  public static let shared = HLSDownloadManager()
  
  public var downloads: [NewDownloadModel] = [] {
    didSet {
      saveDownloads()
      notifyDownloadsChanged()
    }
  }
  
  private let assetDownloader = AssetDownloader()
  
    private init() {
        downloads.append(contentsOf: DownloadMetadataCacheManager.shared.get())
        assetDownloader.delegate = self
    }
    
    public func resume(
        _ download: NewDownloadModel,
        licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl? = nil
    ) {
        if downloads.firstIndex(of: download) == nil {
            // New download
            // TODO: scaricare sottotitoli esterni
            let url = URL(string: download.url)!
            let asset = AVURLAsset(url: url)
            
            assetDownloader.resume(
                assetInfo: AssetInfo(
                    identifier: download.identifier,
                    avUrlAsset: asset,
                    licenseData: nil,
                    bitrate: nil // download.bitrate
                )
            )
            
            downloads.append(download)
        }
        
        /*
      if let download = get(download), let url = download.location {
          let avAsset = AVURLAsset(url: url)
          assetDownloader.resume(assetInfo: AssetInfo(identifier: download.identifier, avUrlAsset: avAsset, licenseData: nil, bitrate: download.bitrate))
      } else if let url = download.location {
          RCTExternalSubtitlesCacheManager.shared.downloadSubtitles(videoId: download.identifier, subtitles: download.externalSubtitles) { [weak self] subtitles, err in
              guard let self else { return }
              if let err = err {
                  self.notifyError(error: err, download: download)
                  return
              }
              downloads.append(download)
              let avAsset = AVURLAsset(url: url)
              self.assetDownloader.resume(assetInfo: AssetInfo(identifier: download.identifier, avUrlAsset: avAsset, licenseData: licenseData))
          }
      }
         */
  }
  
  public func renew(download: DownloadModel, licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) {
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
  
  public func pause(_ download: NewDownloadModel) {
      if let identifier = get(download)?.identifier {
          assetDownloader.cancelDownloadOfAsset(identifier: identifier)
      }
  }
  
    public func get(_ download: NewDownloadModel) -> NewDownloadModel? {
        return downloads.first(where: { model in
            model.identifier == download.identifier
        })
    }
  
  public func getDownload(assetInfo: AssetInfo) -> NewDownloadModel? {
      return downloads.first(where: { model in
          model.identifier == assetInfo.identifier
      })
  }
  
  public func delete(_ download: NewDownloadModel) {
      
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
  
    public func notifyError(error: Error, download: NewDownloadModel) {
        DownloadEventEmitter.shared?.dispatch(
            withName: SupportedDownloadEventEmitterEvents.onDownloadError.rawValue,
            body: DownloadError(
                with: download,
                msg: error.localizedDescription
            ).toDictionary()
        )
    }
  
    private func updateDownloads(
        assetInfo: AssetInfo,
        status: AssetInfo.RAIAVAssetStatus? = nil,
        loaded: Double? = nil,
        total: Double? = nil,
        location: URL? = nil,
        ckcData: Data? = nil
    ) {
        downloads.modifyForEach { index, element in
            if element.identifier == assetInfo.identifier {
                if let status = status {
                    element.state = status
                }
                // if let loaded = loaded, let total = total {
                //     element.progress = RCTDownloadProgress(downloaded: loaded, total: total)
                // }
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
  
    public func saveDownloads() {
        DownloadMetadataCacheManager.shared.save(downloads)
    }
    
    public func notifyDownloadsChanged() {
        let body = downloads.map { model in
            return model.toDictionary()
        }
        DownloadEventEmitter.shared?.dispatch(
            withName: SupportedDownloadEventEmitterEvents.onDownloadListChanged.rawValue,
            body: body
        )
    }
  
  public func notifyRenewLicense(download: DownloadModel, result: Bool) {
    let payload = RenewLicensePayload(item: RCTDownloadItem(model: download), result: result)
    DownloadEventEmitter.shared?.dispatch(withName: SupportedDownloadEventEmitterEvents.onDownloadListChanged.rawValue, body: payload.toDictionary())
  }
}

extension HLSDownloadManager: AssetDownloaderDelegate {
    
    func downloadStatusChanged(assetInfo: AssetInfo, status: AssetInfo.RAIAVAssetStatus) {
        updateDownloads(assetInfo: assetInfo, status: status)
    }
    
    func downloadProgess(assetInfo: AssetInfo, percentage: Double, loaded: Double, total: Double) {
        updateDownloads(assetInfo: assetInfo, loaded: loaded, total: total)
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
