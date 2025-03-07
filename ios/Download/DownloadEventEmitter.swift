//
//  DownloadEventEmitter.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

@objc(DownloadEventEmitter)
class DownloadEventEmitter: RCTEventEmitter {
    
    var hasListener: Bool = false
    
    override func startObserving() {
        hasListener = true
    }
    
    override func stopObserving() {
        hasListener = false
    }
    
    override class func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    public static var shared: DownloadEventEmitter?
    
    override init() {
        super.init()
        DownloadEventEmitter.shared = self
    }
    
    @objc override func supportedEvents() -> [String] {
        return SupportedDownloadEventEmitterEvents.allCases.map { type in
            type.rawValue
        }
    }
    
    func dispatch(withName: String, body: Any?) {
        if hasListener {
            sendEvent(withName: withName, body: body)
        }
    }
}

public enum SupportedDownloadEventEmitterEvents: String, CaseIterable {
    case onDownloadListChanged
    case onDownloadError
    case onRenewLicense
    case onError
    case onDownloadProgress
}

public enum SupportedPlayerEmitterEvents: String, CaseIterable {
    case onPlayerInstanceStateChanged
    case onIsPlayingChanged
    case onPlayerStateChanged
    case onSeekEnd
    case onBufferStateChanged
    case onTimeUpdate
    case onError
    case onPlayerViewClick
    case onSubtitleChanged
    case onAudioChanged
    case onQualityChanged
    case onSpeedChanged
    case onPipStateChanged
}
