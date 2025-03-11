//
//  AssetDownloader.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation
import UIKit

protocol AssetDownloaderDelegate {
    func downloadStateChanged(assetInfo: AssetInfo, state: DownloadState)
    func downloadProgress(assetInfo: AssetInfo, percentage: Double, loaded: Double, total: Double)
    func downloadError(assetInfo: AssetInfo, error: Error)
    func downloadLocationAvailable(assetInfo: AssetInfo, location: URL)
    func downloadCkcAvailable(assetInfo: AssetInfo, ckc: Data)
}

class AssetDownloader: NSObject {
    
    // The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks
    private var assetDownloadURLSession: AVAssetDownloadURLSession!
    
    // Internal map of AVAssetDownloadTask to its corresponding Asset
    private var activeDownloadsMap = [AVAggregateAssetDownloadTask: (AssetInfo, AssetInfo.RAIAVAssetStatus)]()
    
    var delegate: AssetDownloaderDelegate?
    
    private var drmManagers: [AVPlayerDRMManager] = []
    
    //MARK: - PUBLIC
    
    override init() {
        super.init()
        
        // Create the configuration for the AVAssetDownloadURLSession
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).AssetDownloader")
        
        // Avoid OS scheduling the background request transfers due to battery or performance
        backgroundConfiguration.isDiscretionary = false
        
        // Makes the TCP sockets open even when the app is locked or suspended
        backgroundConfiguration.shouldUseExtendedBackgroundIdleMode = true
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        
        // Create the AVAssetDownloadURLSession using the configuration
        assetDownloadURLSession = AVAssetDownloadURLSession(
            configuration: backgroundConfiguration,
            assetDownloadDelegate: self,
            delegateQueue: queue
        )
    }
    
    func setDelegate(_ delegate: AssetDownloaderDelegate) {
        self.delegate = delegate
    }
    
    func resume(assetInfo: AssetInfo) {
        if let licenseData = assetInfo.licenseData {
            let drmManager = AVPlayerDRMManager(asset: assetInfo.avUrlAsset, licenseData: licenseData)
            
            let drmLicenceBecomeReady: ((Data?) -> Void) = {[weak self] ckcData in
                guard let self = self else { return }
                
                self.drmManagers.removeAll{ $0 == drmManager}
                
                if let ckcData = ckcData {
                    self.delegate?.downloadCkcAvailable(assetInfo: assetInfo, ckc: ckcData)
                    self.startCachingtask(assetInfo: assetInfo)
                } else {
                    self.delegate?.downloadError(assetInfo: assetInfo, error: AssetDownloaderError.ckcError)
                }
            }
            
            let drmLicenceFailed: ((Error) -> Void) = {[weak self] error in
                guard let self = self else { return }
                self.drmManagers.removeAll{ $0 == drmManager}
                self.delegate?.downloadError(assetInfo: assetInfo, error: error)
            }
            drmManager.drmLicenceBecomeReady = drmLicenceBecomeReady
            drmManager.drmLicenceFailed = drmLicenceFailed
            drmManager.start()
            
            drmManagers.append(drmManager)
        } else {
            self.startCachingtask(assetInfo: assetInfo)
        }
    }
    
    func renew(assetInfo: AssetInfo, completion: ((Result<Data, Error>) -> Void)? = nil) {
        let drmManager = AVPlayerDRMManager(asset: assetInfo.avUrlAsset, licenseData: assetInfo.licenseData)
        
        let drmLicenceBecomeReady: ((Data?) -> Void) = {[weak self] ckcData in
            guard let self = self else { return }
            
            self.drmManagers.removeAll{ $0 == drmManager}
            
            if let ckcData = ckcData {
                self.delegate?.downloadCkcAvailable(assetInfo: assetInfo, ckc: ckcData)
                completion?(.success(ckcData))
            } else {
                completion?(.failure(CustomError.build(failureReason: "ckc data not available")))
            }
        }
        
        let drmLicenceFailed: ((Error) -> Void) = {[weak self] error in
            guard let self = self else { return }
            self.drmManagers.removeAll{ $0 == drmManager}
            completion?(.failure(error))
        }
        drmManager.drmLicenceBecomeReady = drmLicenceBecomeReady
        drmManager.drmLicenceFailed = drmLicenceFailed
        drmManager.start()
        
        drmManagers.append(drmManager)
    }
    
    // Canceles the download task
    func cancelDownloadOfAsset(identifier: String) {
        var task: AVAggregateAssetDownloadTask?
        var value: (AssetInfo, AssetInfo.RAIAVAssetStatus)?
        
        for (taskKey, activeDownloadValue) in activeDownloadsMap where identifier == activeDownloadValue.0.identifier {
            task = taskKey
            value = activeDownloadValue
            break
        }
        
        if let task = task, let value = value, value.1 == .Downloading {
            activeDownloadsMap[task] = (value.0,.Paused)
            task.cancel()
            logger.debug("ASSET DOWNLOADER: Cancelling download of \(String(describing: task.taskDescription))")
        }
    }
    
//    func pauseAll() {
//        activeDownloadsMap.forEach { k, v in
//            activeDownloadsMap[k] = (v.0, .Paused)
//            k.cancel()
//        }
//    }
    
    //MARK: - PRIVATE
    
    private func startCachingtask(assetInfo: AssetInfo) {
        let avUrlAsset = assetInfo.avUrlAsset
        
        logger.debug("ASSET DOWNLOADER: Download")
        
        /*
         Creates and initializes an AVAggregateAssetDownloadTask to download multiple AVMediaSelections
         on an AVURLAsset.
         
         For the initial download, we ask the URLSession for an AVAssetDownloadTask with a minimum bitrate
         corresponding with one of the lower bitrate variants in the asset.
         */
        
        var mediaSelections: [AVMediaSelection] = []
        var options: [String: Any]?
        
        //checking if is resume of local file or new download
        if assetInfo.avUrlAsset.url.isFileURL == false {
            var bitrate: Double = 0

            var rates: [Double] = []
            if #available(iOS 15.0, *) {
                avUrlAsset.variants.forEach { variant in
                    if let peak = variant.peakBitRate {
                        rates.append(peak)
                    }
                }
            }
            
            let max = rates.max(by: {$1 > $0})
            let min = rates.min(by: {$1 > $0})
            let median = calculateMedianBitrate(bitrates: rates)
            
            if let min, let max, let median {
              switch DownloadManagerModule.SELECTED_QUALITY {
              case .LOW:
                    bitrate = min
              case .MEDIUM:
                    bitrate = median
              case .HIGH:
                    bitrate = max
                }
                
                options = [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: bitrate]
                assetInfo.bitrate = bitrate
            }
            
            if let audibleGroup = avUrlAsset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                audibleGroup.options.forEach({ option in
                    if let mutableMediaSelection = avUrlAsset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
                        mutableMediaSelection.select(option, in: audibleGroup)
                        mediaSelections.append(mutableMediaSelection)
                    }
                })
            }
            
            if let legibleGroup = avUrlAsset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                legibleGroup.options.forEach({ option in
                    if let mutableMediaSelection = avUrlAsset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
                        mutableMediaSelection.select(option, in: legibleGroup)
                        mediaSelections.append(mutableMediaSelection)
                    }
                })
            }
            
            logger.debug("cachingTask mediaSelections \(mediaSelections.count)")
            logger.debug("cachingTask bitrate \(bitrate)")
        }
        
        //using cached bitrate if download has been resumed after pause
        if let bitrate = assetInfo.bitrate, options == nil {
            options = [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: bitrate]
            assetInfo.bitrate = bitrate
        }
        
        guard let task = self.assetDownloadURLSession.aggregateAssetDownloadTask(with: avUrlAsset, mediaSelections: mediaSelections, assetTitle: assetInfo.identifier, assetArtworkData: nil, options: options)
        else {
            logger.debug("ASSET DOWNLOADER: Failed to create AVAggregateAssetDownloadTask")
            return
        }
        
        // Map active task to asset
        self.activeDownloadsMap[task] = (assetInfo,.Downloading)
        
        task.taskDescription = assetInfo.identifier
        task.resume()
        
        // Notify change state
        self.delegate?.downloadStateChanged(assetInfo: assetInfo, state: .downloading)
    }
}

// MARK: - AVAssetDownloadDelegate
extension AssetDownloader: AVAssetDownloadDelegate {
    // Tells the delegate that the task finished transferring data
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        /*
         This is the ideal place to begin downloading additional media selections
         once the asset itself has finished downloading.
         */
        guard let task = task as? AVAggregateAssetDownloadTask,
              let activeDownloadValue = activeDownloadsMap.removeValue(forKey: task) else { return }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                
                logger.debug("ASSET DOWNLOADER: Downloading was cancelled")
                
                /*
                 This task was canceled, you should perform cleanup using the
                 URL saved from AVAssetDownloadDelegate.urlSession(_:assetDownloadTask:didFinishDownloadingTo:).
                 */
                
                if activeDownloadValue.1 == .Paused {
                    self.delegate?.downloadStateChanged(assetInfo: activeDownloadValue.0, state: .paused)
                }
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                logger.debug("ASSET DOWNLOADER: An unexpected error occured \(error)")
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: error)
                
            default:
                logger.debug("ASSET DOWNLOADER: An unexpected error occured \(error)")
                
#if targetEnvironment(simulator)
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: AssetDownloaderError.simulatorNotSupported)
#else
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: error)
#endif
            }
        } else {
            logger.debug("ASSET DOWNLOADER: Downloading completed with success")
            self.delegate?.downloadStateChanged(assetInfo: activeDownloadValue.0, state: .completed)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
        willDownloadTo location: URL
    ) {
        logger.debug("ASSET DOWNLOADER: location available")
        if let activeDownloadValue = activeDownloadsMap[aggregateAssetDownloadTask] {
            delegate?.downloadLocationAvailable(assetInfo: activeDownloadValue.0, location: location)
        } else {
            logger.debug("ASSET DOWNLOADER: asset not present in activeDownloadsMap")
        }
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange,
        for mediaSelection: AVMediaSelection
    ) {
        // This delegate callback should be used to provide download progress for your AVAssetDownloadTask
        var percentComplete = 0.0
        var loadedTimeRangeSeconds = 0.0
        var timeRangeExpectedToLoadSeconds = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            loadedTimeRangeSeconds += CMTimeGetSeconds(loadedTimeRange.duration)
            timeRangeExpectedToLoadSeconds += CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
            percentComplete += loadedTimeRangeSeconds/timeRangeExpectedToLoadSeconds
        }
        
      logger.debug("ASSET DOWNLOADER caching percent \(percentComplete) of \(String(describing: aggregateAssetDownloadTask.taskDescription))")
        
        // Notify change state
        if let val = activeDownloadsMap[aggregateAssetDownloadTask] {
            delegate?.downloadProgress(assetInfo: val.0, percentage: percentComplete, loaded: loadedTimeRangeSeconds, total: timeRangeExpectedToLoadSeconds)
        }
    }
}

extension AssetDownloader {
    enum AssetDownloaderError: Error {
        case unknowError
        case simulatorNotSupported
        case ckcError
        case drmNotSupported
    }
}

extension AssetDownloader {
    func calculateMedianBitrate(bitrates: [Double]) -> Double? {
        guard !bitrates.isEmpty else { return nil }
        let sorted = bitrates.sorted()
        if sorted.count % 2 == 0 {
            return (sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1]) / 2
        } else {
            return sorted[(sorted.count - 1) / 2]
        }
    }
}
