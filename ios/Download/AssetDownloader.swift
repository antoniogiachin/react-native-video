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
    /// `AVAssetDownloadURLSession` used for managing AVAssetDownloadTasks
    private var session: AVAssetDownloadURLSession?
    
    /// Semaphore to limit the number of simultaneous downloads.
    private let semaphore = DispatchSemaphore(value: 3)
    /// The queue used to manage download tasks.
    private var queue = DispatchQueue(
        label: "com.react-native-video.asset-downloader",
        qos: .userInitiated
    )
    
    /// Internal list of `AVAssetDownloadTask` and its corresponding Info object
    private var downloading: [DownloadInfo] = []
    
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
            start(download: assetInfo)
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
        let item = downloading.first(where: { $0.identifier == identifier })
        
        if let item, let task = item.task, item.state == .downloading {
            task.cancel()
            item.state = .paused
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
        
        info.task = task
        info.state = .downloading
        downloading.append(info)
        
        task.taskDescription = info.identifier
        
        // Notify change state
        delegate?.downloadStateChanged(assetInfo: info, state: .downloading)
        
        // Limiting the number of simultaneous downloads
        queue.async { [weak self] in
            self?.semaphore.wait()
            task.resume()
        }
    }
}

// MARK: - AVAssetDownloadDelegate
extension AssetDownloader: AVAssetDownloadDelegate {
    func item(for task: URLSessionTask) -> DownloadInfo? {
        downloading.first(where: { $0.task == task })
    }
    
    // Tells the delegate that the task finished transferring data
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        defer {
            // Proceeding with the next download
            semaphore.signal()
        }
        
        guard let item = item(for: task) else {
            // Not found
            return
        }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                debugPrint("ASSET DOWNLOADER: Downloading was cancelled")
                
                /*
                 This task was canceled, you should perform cleanup using the
                 URL saved from AVAssetDownloadDelegate.urlSession(_:assetDownloadTask:didFinishDownloadingTo:).
                 */
                
                if item.state == .paused {
                    delegate?.downloadStateChanged(assetInfo: item, state: .paused)
                }
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                self.delegate?.downloadError(assetInfo: item, error: error)
                
            default:
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                
#if targetEnvironment(simulator)
                delegate?.downloadError(assetInfo: item, error: AssetDownloaderError.simulatorNotSupported)
#else
                delegate?.downloadError(assetInfo: item, error: error)
#endif
            }
        } else {
            debugPrint("ASSET DOWNLOADER: Downloading completed with success")
            delegate?.downloadStateChanged(assetInfo: item, state: .completed)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask task: AVAggregateAssetDownloadTask,
        willDownloadTo location: URL
    ) {
        debugPrint("ASSET DOWNLOADER: location available")
        
        guard let item = item(for: task) else {
            // Not found
            debugPrint("ASSET DOWNLOADER: asset not present in activeDownloadsMap")
            return
        }
        
        delegate?.downloadLocationAvailable(assetInfo: item, location: location)
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask task: AVAggregateAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange,
        for mediaSelection: AVMediaSelection
    ) {
        // This delegate callback should be used to provide download progress for your AVAssetDownloadTask
        var percentage = 0.0
        var loaded = 0.0
        var total = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            loaded += CMTimeGetSeconds(loadedTimeRange.duration)
            total += CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
            percentage += loaded / total
        }
        
        debugPrint("ASSET DOWNLOADER caching percent \(percentage) of \(String(describing: task.taskDescription))")
        
        guard let item = item(for: task) else {
            // Not found
            return
        }
        
        // Notify change state
        delegate?.downloadProgress(
            assetInfo: item,
            percentage: percentage,
            loaded: loaded,
            total: total
        )
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
