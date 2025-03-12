//
//  AVPlayerDRMManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

public protocol AVPlayerDRMManagerDelegate : AnyObject {
    func drmLicenceBecomeReady()
    func drmLicenceFailed(error: Error)
}

public class AVPlayerDRMManager: Hashable  {
    
    public weak var delegate: AVPlayerDRMManagerDelegate?
    
    public var drmLicenceBecomeReady: ((Data?) -> Void)? {
        didSet{
            if #available(iOS 11.2, *) {
                if let keySessionDelegate = keySessionDelegate as? DRMKeySessionDelegate {
                    keySessionDelegate.drmLicenceBecomeReady = drmLicenceBecomeReady
                }
            }
        }
    }
    
    public var drmLicenceFailed: ((Error) -> Void)? {
        didSet{
            if #available(iOS 11.2, *) {
                if let keySessionDelegate = keySessionDelegate as? DRMKeySessionDelegate {
                    keySessionDelegate.drmLicenceFailed = drmLicenceFailed
                }
            }
        }
    }
    
    private weak var asset : AVURLAsset?
    private var licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?
    private var ckcData: Data? = nil, certificateData: Data? = nil
    private var isFromPlayer: Bool = true
    
    private var contentKeySession : Any?
    private var keySessionDelegate: Any?
    var item: AVPlayerItem?
    var player: AVPlayer?
    
    ///Initializer for online content passing licenseData or offline content passing licenseData and ckcData.
    ///If you have certificateData you can use it or manager will use default certificate.
    public init(asset: AVURLAsset, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?, ckcData: Data?, certificateData: Data? = nil)  {
        self.asset = asset
        self.licenseData = licenseData
        self.ckcData = ckcData
        self.certificateData = certificateData
        self.isFromPlayer = true
    }
    
    ///Initializer for caching task. If you have certificateData you can use it or manager will use default certificate.
    public convenience init(asset: AVURLAsset, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?, certificateData: Data? = nil)  {
        self.init(asset: asset, licenseData: licenseData, ckcData: nil, certificateData: certificateData)
        self.isFromPlayer = false
    }
    
    public func start(){
#if targetEnvironment(simulator)
#else
        if #available(iOS 11.2, *) {
            var delegate: DRMKeySessionDelegate?
            
            if isFromPlayer {
                delegate =  DRMKeySessionDelegate(delegate: self.delegate, licenseData: licenseData, ckcData: ckcData, certificateData: certificateData)
            } else {
                delegate = DRMKeySessionDelegate(delegate: self.delegate, licenseData: licenseData)
            }
            
            let drmLicenceBecomeReady: ((Data?) -> Void) = { [weak self] license in
                self?.drmLicenceBecomeReady?(license)
                self?.player = nil
                self?.item = nil
            }
            
            let drmLicenceFailed: ((Error) -> Void) = { [weak self] error in
                self?.drmLicenceFailed?(error)
                self?.player = nil
                self?.item = nil
            }
            
            delegate?.drmLicenceBecomeReady = drmLicenceBecomeReady
            delegate?.drmLicenceFailed = drmLicenceFailed
            
            let session = AVContentKeySession(keySystem: .fairPlayStreaming)
            
            self.keySessionDelegate = delegate
            self.contentKeySession = session
            
            if let asset = self.asset, asset.hasProtectedContent == true {
                session.setDelegate(delegate, queue: .global(qos: .userInteractive))
                session.addContentKeyRecipient(asset)
                if !isFromPlayer && licenseData != nil {
                    self.item = AVPlayerItem(asset: asset)
                    self.player = AVPlayer(playerItem: item)
                }
            } else {
                drmLicenceFailed(CustomError.build(failureReason: "Called RAIPlayerAVPlayerDRMManager but doesn't exists protect content"))
            }
        }
#endif
    }
    
    private func clear() {
        self.keySessionDelegate = nil
        self.contentKeySession = nil
        self.item = nil
        self.player = nil
    }
    
    public func restart(){
        self.clear()
        self.start()
    }
    
    public static func == (lhs: AVPlayerDRMManager, rhs: AVPlayerDRMManager) -> Bool {
        return lhs.asset == rhs.asset
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(asset?.url)
    }
}

public class AVPlayerDRMManagerLicenseDownloader {
    public func download(licenseUrl: String, spcData: Data, completion: @escaping (Data?, Error?) -> Void){
        
    }
    
    public class func getInstanceBy(drmOperator: DRMOperator) -> AVPlayerDRMManagerLicenseDownloader? {
        if drmOperator == .verimatrix {
            return AVPlayerDRMManagerLicenseDownloaderVerimatrix()
        }else if drmOperator == .azure {
            return AVPlayerDRMManagerLicenseDownloaderAzure()
        }else if drmOperator == .nagra {
            return AVPlayerDRMManagerLicenseDownloaderNagra()
        }
        return nil
    }
}
