//
//  DRMKeySessionDelegate.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation


public enum DRMKeySessionDelegateError: Error {
    case noContentId
    case noCertificateData
    case noSPCData
    case ckcFetch
    case drmOperatorNotSupported
    case noLicenseUrl
    case noMediapolisLicenseData
}

@available(iOS 11.2, *)
public class DRMKeySessionDelegate : NSObject, AVContentKeySessionDelegate {
   
    private weak var delegate: AVPlayerDRMManagerDelegate?
    private weak var licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?
    
    public var drmLicenceBecomeReady: ((Data?) -> Void)?
    public var drmLicenceFailed: ((Error) -> Void)?
    public var drmIdentifierDidBecomeReady: ((String?) -> Void)?
    
    private var cachedCertificateData: Data?
    private var maxRetry: Int = 5
    private var currentRetry: Int = 0
    private var ckcData: Data?
    private var saveCkc: Bool = false
    private var identifier: String?
    
    ///Initializer for online content passing licenseData or offline content passing licenseData and ckcData.
    ///If you have certificateData you can use it or delegate will use default certificate.
    public init(delegate: AVPlayerDRMManagerDelegate?, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?, ckcData: Data?, certificateData: Data? = nil) {
        self.delegate = delegate
        self.licenseData = licenseData
        self.ckcData = ckcData
        self.cachedCertificateData = certificateData
        self.saveCkc = false
    }
    
    ///Initializer for caching task. If you have certificateData you can use it or delegate will use default certificate.
    public convenience init(delegate: AVPlayerDRMManagerDelegate?, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?, certificateData: Data? = nil) {
        self.init(delegate: delegate, licenseData: licenseData, ckcData: nil, certificateData: certificateData)
        self.saveCkc = true
    }
    
    public func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: Error) {
        logger.error("contentKeyRequest failed: \(err)")
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.drmLicenceFailed(error: err)
            self?.drmLicenceFailed?(err)
        }
    }
    
    public func contentKeySession(_ session: AVContentKeySession, contentKeyRequestDidSucceed keyRequest: AVContentKeyRequest) {
        logger.debug("contentKeyRequest successfully")
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.drmLicenceBecomeReady()
            self?.drmLicenceBecomeReady?(self?.ckcData)
        }
    }

    public func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        #if os(tvOS)
            getContentkey(keyRequest: keyRequest)
        #else
            if saveCkc == false && ckcData == nil {
                getContentkey(keyRequest: keyRequest)
            } else {
                if keyRequest.canProvidePersistableContentKey, let persistableKeyRequest = keyRequest as? AVPersistableContentKeyRequest {
                  contentKeySession(session, didProvide: persistableKeyRequest)
                } else {
                    do {
                        try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
                    } catch {
                        keyRequest.processContentKeyResponseError(error)
                    }
                }
            }
        #endif
    }

    public func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        clearCahcedData()
        getContentkey(keyRequest: keyRequest)
    }

    public func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVPersistableContentKeyRequest) {
        getContentkey(keyRequest: keyRequest)
    }

    #if !os(tvOS)
    public func contentKeySession(_ session: AVContentKeySession, didUpdatePersistableContentKey persistableContentKey: Data, forContentKeyIdentifier keyIdentifier: Any) {
        logger.debug("contentKeyRequest didUpdatePersistableContentKey")
        
        self.ckcData = persistableContentKey
    
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.drmLicenceBecomeReady()
            self?.drmLicenceBecomeReady?(self?.ckcData)
        }
    }
    #endif
    
    private func clearCahcedData() {
        ckcData = nil
    }

    private func getContentkey(keyRequest: AVContentKeyRequest) {
        currentRetry = currentRetry + 1
        
        logger.debug("contentKeyRequest begin retry: \(currentRetry)")
        
        if let ckcData = ckcData, let keyRequest = keyRequest as? AVPersistableContentKeyRequest {
            let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
            keyRequest.processContentKeyResponse(keyResponse)
            return
        }
        
        guard let licenseData = self.licenseData else {
            logger.error("fairplay license no found")
            keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.noMediapolisLicenseData)
            return
        }

        guard let contentKeyIdentifierString = keyRequest.identifier as? String, let assetIDData = DRMAssetIdGenerator.getInstanceBy(drmOperator: licenseData.drmOperator).generate(contentKeyIdentifier: contentKeyIdentifierString)
        else {
            let errorMessage = "failed to retrieve the assetID from the keyRequest!"
            logger.error(errorMessage)
            keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.noContentId)
            return
        }
        
        let keyRequestCompletionHandler = { (spcData: Data?, error: Error?) in
            
            logger.debug("begin downloading license with url '\(licenseData.fullLicenseUrl ?? "nil")'")
            
            if let licenseUrl = licenseData.fullLicenseUrl {
                if let spcData = spcData {
                    
                    if let downloader = AVPlayerDRMManagerLicenseDownloader.getInstanceBy(drmOperator: licenseData.drmOperator) {
                        logger.debug("downloading license for '\(licenseData.drmOperator)'")
                        downloader.download(licenseUrl: licenseUrl, spcData: spcData) { ckcData, error in
                            
                            if let error = error {
                                let errorMessage = "download licence failed for '\(licenseData.drmOperator)': \(error)"
                                logger.error(errorMessage)
                                keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.ckcFetch)
                            }else if let ckcData = ckcData {
                                logger.debug("download licence successfully for '\(licenseData.drmOperator)'")
                                
                                if let keyRequest = keyRequest as? AVPersistableContentKeyRequest {
                                    do {
                                        let persistentKeyData: Data = try keyRequest.persistableContentKey(fromKeyVendorResponse: ckcData, options: nil)
                                        self.ckcData = persistentKeyData
                                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: persistentKeyData)
                                        keyRequest.processContentKeyResponse(keyResponse)
                                    } catch {
                                        logger.error("Unable to create persistable content key \(error).")
                                        keyRequest.processContentKeyResponseError(error)
                                    }
                                } else {
                                    let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                                    keyRequest.processContentKeyResponse(keyResponse)
                                }
                                

                            }
                        }
                    }else{
                        logger.warning("no downloader impl found for '\(licenseData.drmOperator)'")
                        keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.drmOperatorNotSupported)
                    }
                }else{
                    logger.warning("keyRequestCompletionHandler error data corrupted?: \(String(describing: error))")
                    keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.noSPCData)
                }
            }else{
                logger.warning("keyRequestCompletionHandler licenseUrl is nil")
                keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.noLicenseUrl)
            }
        }
        
        // download certificate
        if let certificateData = self.cachedCertificateData {
            logger.debug("use cached certificate")
            keyRequest.makeStreamingContentKeyRequestData(
                forApp: certificateData,
                contentIdentifier: assetIDData,
                options: [AVContentKeyRequestProtocolVersionsKey: [1]/*, AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true*/],
                completionHandler: keyRequestCompletionHandler)
        }else{
            if let certificateUrl = ConfigManager.shared.drmCertificates[.fairplay] {

                NetworkManager.sessionManager()
                    .request(certificateUrl, method: .get)
                    .validate(statusCode: 200..<300)
                    .responseData { response in
                        switch response.result {

                        case .success(let value):
                            self.cachedCertificateData = value

                            logger.debug("download certificate successfully")
                            keyRequest.makeStreamingContentKeyRequestData(
                                forApp: value,
                                contentIdentifier: assetIDData,
                                options: [AVContentKeyRequestProtocolVersionsKey: [1]/*, AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true*/],
                                completionHandler: keyRequestCompletionHandler)

                        case .failure(let error):
                            let errorMessage = "download certificateData failed: \(error)"
                            logger.error(errorMessage)
                            keyRequest.processContentKeyResponseError(DRMKeySessionDelegateError.noCertificateData)
                        }
                }
            }
        }
    }
}
