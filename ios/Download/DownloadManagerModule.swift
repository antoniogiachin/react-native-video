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
    
    @objc func prepare() {
        HLSDownloadManager.shared.notifyDownloadsChanged()
    }
    
    @objc func start(_ item: NSDictionary) {
        getModelFromDictElseNotifyError(item: item) { model, licenseData in
            HLSDownloadManager.shared.resume(model, licenseData: licenseData)
        }
    }
    
    @objc func resume(_ item: NSDictionary) {
        getModelFromDictElseNotifyError(item: item) { model, _ in
            HLSDownloadManager.shared.resume(model)
        }
    }
    
    @objc func pause(_ item: NSDictionary) {
        getModelFromDictElseNotifyError(item: item) { model, _ in
            HLSDownloadManager.shared.pause(model)
        }
    }
    
    @objc func delete(_ item: NSDictionary) {
        if let model = DownloadModel(input: item) {
            HLSDownloadManager.shared.delete(model)
        }
    }
    
    @objc func batchDelete(_ items: [NSDictionary]) {
        for item in items {
            if let model = DownloadModel(input: item) {
                HLSDownloadManager.shared.delete(model)
            }
        }
    }
    
    @objc func renewDrmLicense(_ item: NSDictionary) {
        getModelFromDictElseNotifyError(item: item) { model, licenseData in
            HLSDownloadManager.shared.renew(download: model, licenseData: licenseData)
        }
    }
    
    @objc func setQuality(_ quality: NSString) {
        DownloadManagerModule.SELECTED_QUALITY = DownloadQualityOptions(rawValue: quality as String) ?? .MEDIUM
    }
    
    private func getModelFromDictElseNotifyError(
        item: NSDictionary,
        callback: (DownloadModel, RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) -> Void
    ) {
        guard let downloadInput = DownloadModel(input: item) else {
            DownloadEventEmitter.shared?.dispatch(
                withName: SupportedPlayerEmitterEvents.onError.rawValue,
                body: DownloadError(
                    downloadInput: item,
                    msg: "cannot run download task, it's possible that pathId, programPathId or ua is missing"
                )
            )
            return
        }
        
        guard let drm = item["drm"] as? NSDictionary else {
            callback(downloadInput, nil)
            return
        }
        
        let licenseData = RCTMediapolisModelLicenceServerMapDRMLicenceUrl(dictionary: drm)
        callback(downloadInput, licenseData)
    }
    
    @objc func getDownloadList(
        _ ua: String,
        resolver: @escaping RCTPromiseResolveBlock,
        rejecter: @escaping RCTPromiseRejectBlock
    ) {
        let downloads = HLSDownloadManager.shared.downloads
        resolver(downloads.map { $0.toDictionary() })
    }
}
