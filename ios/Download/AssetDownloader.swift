//
//  AssetDownloader.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import UIKit
import AVFoundation

protocol AssetDownloaderDelegate {
    func downloadStateChanged(assetInfo: DownloadInfo, state: DownloadState)
    func downloadProgress(assetInfo: DownloadInfo, percentage: Double, loaded: Double, total: Double)
    func downloadError(assetInfo: DownloadInfo, error: Error)
    func downloadLocationAvailable(assetInfo: DownloadInfo, location: URL)
    func downloadCkcAvailable(assetInfo: DownloadInfo, ckc: Data)
}

class AssetDownloader: NSObject {
    // The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks
    private var session: AVAssetDownloadURLSession?
    
    // Internal map of AVAssetDownloadTask to its corresponding Asset
    private var downloading = [
        AVAggregateAssetDownloadTask: (DownloadInfo, DownloadInfo.RAIAVAssetStatus)
    ]()
    
    var delegate: AssetDownloaderDelegate?
    
    private var drmManagers: [AVPlayerDRMManager] = []
    
    //MARK: - PUBLIC
    
    override init() {
        super.init()
        
        // Create the configuration for the AVAssetDownloadURLSession
        let bundle = Bundle.main.bundleIdentifier ?? ""
        let configuration = URLSessionConfiguration.background(
            withIdentifier: "\(bundle).AssetDownloader"
        )
        
        // Avoid OS scheduling the background request transfers due to battery or performance
        configuration.isDiscretionary = false
        
        // Makes the TCP sockets open even when the app is locked or suspended
        configuration.shouldUseExtendedBackgroundIdleMode = true
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        
        // Create the AVAssetDownloadURLSession using the configuration
        session = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: queue
        )
    }
    
    func setDelegate(_ delegate: AssetDownloaderDelegate) {
        self.delegate = delegate
    }
    
    func resume(assetInfo: DownloadInfo) {
        if let licenseData = assetInfo.licenseData {
            let drmManager = AVPlayerDRMManager(asset: assetInfo.asset, licenseData: licenseData)
            
            let drmLicenceBecomeReady: ((Data?) -> Void) = {[weak self] ckcData in
                guard let self else { return }
                
                self.drmManagers.removeAll{ $0 == drmManager}
                
                if let ckcData {
                    self.delegate?.downloadCkcAvailable(assetInfo: assetInfo, ckc: ckcData)
                    self.start(download: assetInfo)
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
            self.start(download: assetInfo)
        }
    }
    
    func renew(assetInfo: DownloadInfo, completion: ((Result<Data, Error>) -> Void)? = nil) {
        let drmManager = AVPlayerDRMManager(asset: assetInfo.asset, licenseData: assetInfo.licenseData)
        
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
    
    // Cancels the download task
    func cancelDownloadOfAsset(identifier: String) {
        var task: AVAggregateAssetDownloadTask?
        var value: (DownloadInfo, DownloadInfo.RAIAVAssetStatus)?
        
        for (taskKey, activeDownloadValue) in downloading where identifier == activeDownloadValue.0.identifier {
            task = taskKey
            value = activeDownloadValue
            break
        }
        
        if let task, let value, value.1 == .Downloading {
            downloading[task] = (value.0,.Paused)
            task.cancel()
            debugPrint("ASSET DOWNLOADER: Cancelling download of \(String(describing: task.taskDescription))")
        }
    }
    
//    func pauseAll() {
//        activeDownloadsMap.forEach { k, v in
//            activeDownloadsMap[k] = (v.0, .Paused)
//            k.cancel()
//        }
//    }
    
    //MARK: - PRIVATE
    
    private func start(download info: DownloadInfo) {
        let asset = info.asset
        
        debugPrint("ASSET DOWNLOADER: Download")
        
        /*
         Creates and initializes an AVAggregateAssetDownloadTask to download multiple AVMediaSelections
         on an AVURLAsset.
         
         For the initial download, we ask the URLSession for an AVAssetDownloadTask with a minimum bitrate
         corresponding with one of the lower bitrate variants in the asset.
         */
        
        var mediaSelections: [AVMediaSelection] = []
        var options: [String: Any]?
        
        //checking if is resume of local file or new download
        if asset.url.isFileURL == false {
            var bitrate: Double = 0

            var rates: [Double] = []
            if #available(iOS 15.0, *) {
                asset.variants.forEach { variant in
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
                info.bitrate = bitrate
            }
            
            if let audibleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                audibleGroup.options.forEach({ option in
                    if let mutableMediaSelection = asset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
                        mutableMediaSelection.select(option, in: audibleGroup)
                        mediaSelections.append(mutableMediaSelection)
                    }
                })
            }
            
            if let legibleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                legibleGroup.options.forEach({ option in
                    if let mutableMediaSelection = asset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
                        mutableMediaSelection.select(option, in: legibleGroup)
                        mediaSelections.append(mutableMediaSelection)
                    }
                })
            }
            
            debugPrint("cachingTask mediaSelections \(mediaSelections.count)")
            debugPrint("cachingTask bitrate \(bitrate)")
        }
        
        //using cached bitrate if download has been resumed after pause
        if let bitrate = info.bitrate, options == nil {
            options = [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: bitrate]
            info.bitrate = bitrate
        }
        
        // Creating the download task
        guard let task = session?.aggregateAssetDownloadTask(
            with: asset,
            mediaSelections: mediaSelections,
            assetTitle: info.identifier,
            assetArtworkData: nil,
            options: options
        )
        else {
            debugPrint("ASSET DOWNLOADER: Failed to create AVAggregateAssetDownloadTask")
            return
        }
        
        downloading[task] = (info, .Downloading)
        
        task.taskDescription = info.identifier
        task.resume()
        
        // Notify change state
        self.delegate?.downloadStateChanged(assetInfo: info, state: .downloading)
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
              let activeDownloadValue = downloading.removeValue(forKey: task) else { return }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                
                debugPrint("ASSET DOWNLOADER: Downloading was cancelled")
                
                /*
                 This task was canceled, you should perform cleanup using the
                 URL saved from AVAssetDownloadDelegate.urlSession(_:assetDownloadTask:didFinishDownloadingTo:).
                 */
                
                if activeDownloadValue.1 == .Paused {
                    self.delegate?.downloadStateChanged(assetInfo: activeDownloadValue.0, state: .paused)
                }
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: error)
                
            default:
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                
#if targetEnvironment(simulator)
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: AssetDownloaderError.simulatorNotSupported)
#else
                self.delegate?.downloadError(assetInfo: activeDownloadValue.0, error: error)
#endif
            }
        } else {
            debugPrint("ASSET DOWNLOADER: Downloading completed with success")
            self.delegate?.downloadStateChanged(assetInfo: activeDownloadValue.0, state: .completed)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
        willDownloadTo location: URL
    ) {
        debugPrint("ASSET DOWNLOADER: location available")
        if let activeDownloadValue = downloading[aggregateAssetDownloadTask] {
            delegate?.downloadLocationAvailable(assetInfo: activeDownloadValue.0, location: location)
        } else {
            debugPrint("ASSET DOWNLOADER: asset not present in activeDownloadsMap")
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
        
        debugPrint("ASSET DOWNLOADER caching percent \(percentComplete) of \(String(describing: aggregateAssetDownloadTask.taskDescription))")
        
        // Notify change state
        if let val = downloading[aggregateAssetDownloadTask] {
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
