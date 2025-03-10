//
//  DownloadManagerModule.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import React

@objc(DownloadManagerModule)
class DownloadManagerModule: RCTEventEmitter {
    
    public static var SELECTED_QUALITY: DownloadQualityOptions = .MEDIUM
    
    @objc func prepare() {
        HLSDownloadManager.shared.notifyDownloadsChanged()
    }
    
    @objc func start(_ item: [String: Any]) {
        getModelFromDictElseNotifyError(item) { model, licenseData in
            HLSDownloadManager.shared.resume(model, licenseData: licenseData)
        }
    }
    
    @objc func resume(_ item: [String: Any]) {
        getModelFromDictElseNotifyError(item) { model, _ in
            HLSDownloadManager.shared.resume(model)
        }
    }
    
    @objc func pause(_ item: [String: Any]) {
        getModelFromDictElseNotifyError(item) { model, _ in
            HLSDownloadManager.shared.pause(model)
        }
    }
    
    @objc func delete(_ item: [String: Any]) {
        if let model = NewDownloadModel.from(item) {
            HLSDownloadManager.shared.delete(model)
        }
    }
    
    @objc func batchDelete(_ items: [[String: Any]]) {
        for item in items {
            if let model = NewDownloadModel.from(item) {
                HLSDownloadManager.shared.delete(model)
            }
        }
    }
    
    @objc func renewDrmLicense(_ item: [String: Any]) {
        getModelFromDictElseNotifyError(item) { model, licenseData in
//            HLSDownloadManager.shared.renew(download: model, licenseData: licenseData)
        }
    }
    
    @objc func setQuality(_ quality: String) {
        DownloadManagerModule.SELECTED_QUALITY = DownloadQualityOptions(rawValue: quality) ?? .MEDIUM
    }
    
    private func getModelFromDictElseNotifyError(
        _ item: [String: Any],
        callback: (NewDownloadModel, RCTMediapolisModelLicenceServerMapDRMLicenceUrl?) -> Void
    ) {
        guard let download = NewDownloadModel.from(item) else {
            DownloadManagerModule.sendEvent(
                .onDownloadError,
                body: DownloadError(
                    download: item,
                    msg: "cannot run download task, it's possible that pathId, programPathId or ua is missing"
                )
            )
            return
        }
        
        guard let drm = item["drm"] as? NSDictionary else {
            callback(download, nil)
            return
        }
        
        let licenseData = RCTMediapolisModelLicenceServerMapDRMLicenceUrl(dictionary: drm)
        callback(download, licenseData)
    }
    
    @objc func getDownloadList(
        _ ua: String,
        resolver: @escaping RCTPromiseResolveBlock,
        rejecter: @escaping RCTPromiseRejectBlock
    ) {
        let downloads = HLSDownloadManager.shared.downloads
        resolver(downloads.map { $0.toDictionary() })
    }
    
    // MARK: - Event emitter
    
    public override class func requiresMainQueueSetup() -> Bool {
        false
    }
    
    private var hasListener: Bool = false
    
    override func startObserving() {
        hasListener = true
    }
    
    override func stopObserving() {
        hasListener = false
    }
    
    private static var shared: DownloadManagerModule?
    
    override init() {
        super.init()
        DownloadManagerModule.shared = self
    }
    
    static func sendEvent(_ event: DownloadManagerModuleEvent, body: Any) {
        shared?.sendEvent(withName: event.rawValue, body: body)
    }
    
    override func sendEvent(withName name: String, body: Any) {
        if hasListener {
            super.sendEvent(withName: name, body: body)
        }
    }
    
    override func supportedEvents() -> [String] {
        DownloadManagerModuleEvent.allCases.map { $0.rawValue }
    }
}

enum DownloadManagerModuleEvent: String, CaseIterable {
    case onDownloadListChanged
    case onDownloadError
    case onRenewLicense
    case onError
    case onDownloadProgress
}
