//
//  DownloadManagerModule.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

@objc(DownloadManagerModule)
public class DownloadManagerModule: NSObject {

  public static var SELECTED_QUALITY: DownloadQualityOptions = .MEDIUM
  
  @objc(prepare)
  func prepare() {
    HLSDownloadManager.shared.notifyDownloadsChanged()
  }
  
  @objc(start:)
  func start(item: NSDictionary) {
      getModelFromDictElseNotifyError(item: item) { model, licenseData in
          HLSDownloadManager.shared.resume(download: model, licenseData: licenseData)
      }
  }
  
  @objc(resume:)
  func resume(item: NSDictionary) {
      getModelFromDictElseNotifyError(item: item) { model, _ in
          HLSDownloadManager.shared.resume(download: model)
      }

  }
  
  @objc(pause:)
  func pause(item: NSDictionary) {
      getModelFromDictElseNotifyError(item: item) { model, _ in
          HLSDownloadManager.shared.pause(download: model)
      }
  }
  
  @objc(delete:)
  func delete(item: NSDictionary) {
      getModelFromDictElseNotifyError(item: item) { model, _ in
          HLSDownloadManager.shared.deleteDownload(download: model)
      }
  }
  
  @objc(renewDrmLicense:)
  func renewDrmLicense(item: NSDictionary) {
      getModelFromDictElseNotifyError(item: item) { model, licenseData in
          HLSDownloadManager.shared.renew(download: model, licenseData: licenseData)
      }
  }
  
  @objc(setQuality:)
  func setQuality(quality: NSString) {
    DownloadManagerModule.SELECTED_QUALITY = DownloadQualityOptions(rawValue: quality as String) ?? .MEDIUM
  }
  
  func getModelFromDictElseNotifyError(item: NSDictionary, callback: (DownloadModel, RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) -> Void) {
      guard let downloadInput = DownloadModel(input: item) else {
          DownloadEventEmitter.shared?.dispatch(withName: SupportedPlayerEmitterEvents.onError.rawValue, body: DownloadError(downloadInput: item, msg: "cannot run download task, it's possible that pathId, programPathId or ua is missing"))
          return
      }
      var licenseData: RCTMediapolisModelLicenceServerMapDRMLicenceUrl?
      if let drm = item["drm"] as? NSDictionary {
          licenseData = RCTMediapolisModelLicenceServerMapDRMLicenceUrl(dictionary: drm)
      }
      callback(downloadInput, licenseData)
  }
  
}
