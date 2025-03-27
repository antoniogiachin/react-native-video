//
//  AssetDownloader.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import UIKit
import AVFoundation

protocol AssetDownloaderDelegate: NSObjectProtocol {
    func downloadStateChanged(_ info: DownloadAssetTaskModel, state: DownloadState)
    func downloadProgress(_ info: DownloadAssetTaskModel, loaded: Int, total: Int)
    func downloadError(_ info: DownloadAssetTaskModel, error: Error)
    func downloadLocationAvailable(_ info: DownloadAssetTaskModel, location: URL)
    func downloadCkcAvailable(_ info: DownloadAssetTaskModel, ckc: Data)
}

class AssetDownloader: NSObject, DownloadLogging {
    /// `AVAssetDownloadURLSession` used for managing AVAssetDownloadTasks.
    private var session: AVAssetDownloadURLSession?
    
    /// Semaphore to limit the number of simultaneous downloads.
    private let semaphore = DispatchSemaphore(value: 3)
    /// The queue used to manage download tasks.
    private var queue = DispatchQueue(
        label: "com.react-native-video.asset-downloader",
        qos: .userInitiated
    )
    
    /// Internal list of Info objects and their associated `AVAssetDownloadTask`.
    private var downloading: [DownloadAssetTaskModel] = []
    
    /// Delegate to be informed of changes during downloads.
    weak var delegate: AssetDownloaderDelegate?
    
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
        
        // Create the OperationQueue for the URLSession
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        
        // Create the AVAssetDownloadURLSession using the configuration
        session = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: queue
        )
    }
    
    func resume(_ info: DownloadAssetTaskModel) {
        if let licenseData = info.licenseData {
            let drmManager = AVPlayerDRMManager(asset: info.asset, licenseData: licenseData)
            
            let drmLicenseReady: ((Data?) -> Void) = { [weak self] ckcData in
                guard let self else { return }
                
                drmManagers.removeAll{ $0 == drmManager }
                
                if let ckcData {
                    delegate?.downloadCkcAvailable(info, ckc: ckcData)
                    start(info)
                } else {
                    delegate?.downloadError(info, error: AssetDownloaderError.ckc)
                }
            }
            
            let drmLicenseFailed: ((Error) -> Void) = { [weak self] error in
                guard let self else { return }
                
                drmManagers.removeAll{ $0 == drmManager }
                delegate?.downloadError(info, error: error)
            }
            
            drmManager.drmLicenceBecomeReady = drmLicenseReady
            drmManager.drmLicenceFailed = drmLicenseFailed
            drmManager.start()
            
            drmManagers.append(drmManager)
        } else {
            start(info)
        }
    }
    
    func renew(_ info: DownloadAssetTaskModel, completion: ((Result<Data, Error>) -> Void)? = nil) {
        let drmManager = AVPlayerDRMManager(asset: info.asset, licenseData: info.licenseData)
        
        let drmLicenceBecomeReady: ((Data?) -> Void) = {[weak self] ckcData in
            guard let self else { return }
            
            self.drmManagers.removeAll{ $0 == drmManager}
            
            if let ckcData = ckcData {
                self.delegate?.downloadCkcAvailable(info, ckc: ckcData)
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
    
    /// Cancel the download task.
    func cancel(identifier: String) {
        let item = downloading.first(where: { $0.identifier == identifier })
        
        if let item, let task = item.task {
            task.cancel()
            downloading.remove { $0 == item }
            log(debug: "Cancelled download task: \(item)")
        }
    }
    
    /// Creates and initializes an `AVAggregateAssetDownloadTask` to download multiple `AVMediaSelections` on an `AVURLAsset`.
    private func start(_ info: DownloadAssetTaskModel) {
        let asset = info.asset
        
        log(debug: "Initializing download: \(info)")
        
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
                switch DownloadManagerModule.selectedQuality {
                case .low:
                    bitrate = min
                case .medium:
                    bitrate = median
                case .high:
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
            
            log(verbose: "cachingTask mediaSelections \(mediaSelections.count)")
            log(verbose: "cachingTask bitrate \(bitrate)")
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
            log(error: "Failed to create AVAggregateAssetDownloadTask for \(info)")
            return
        }
        
        info.task = task
        downloading.append(info)
        
        // Notify change state
        delegate?.downloadStateChanged(info, state: .downloading)
        
        // Limiting number of simultaneous downloads
        log(debug: "Queueing download: \(info)")
        log(verbose: "Download url: \(asset.url)")
        queue.async { [weak self] in
            self?.semaphore.wait()
            
            self?.log(debug: "Starting download: \(info)")
            task.resume()
        }
    }
    
    private func calculateMedianBitrate(bitrates: [Double]) -> Double? {
        guard bitrates.isNotEmpty else { return nil }
        
        let sorted = bitrates.sorted()
        if sorted.count % 2 == 0 {
            return (sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1]) / 2
        } else {
            return sorted[(sorted.count - 1) / 2]
        }
    }
}

// MARK: - AVAssetDownloadDelegate
extension AssetDownloader: AVAssetDownloadDelegate {
    /// Helper method to retrieve the DownloadInfo object for a given task.
    private func item(for task: URLSessionTask) -> DownloadAssetTaskModel? {
        downloading.first(where: { $0.task == task })
    }
    
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
        
        // Clean the downloading list
        downloading.remove { $0 == item }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                log(error: "Download was cancelled: \(item)")
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                log(error: "An unknown error occured for \(item): \(error.description)")
                delegate?.downloadError(item, error: error)
                
            default:
                log(error: "An unexpected error occured for \(item): \(error.description)")
                
#if targetEnvironment(simulator)
                delegate?.downloadError(item, error: AssetDownloaderError.simulatorNotSupported)
#else
                delegate?.downloadError(item, error: error)
#endif
            }
        } else {
            log(info: "Download completed: \(item)")
            delegate?.downloadStateChanged(item, state: .completed)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask task: AVAggregateAssetDownloadTask,
        willDownloadTo location: URL
    ) {
        guard let item = item(for: task) else {
            // Not found
            log(error: "Asset not present in the downloading list for task: \(task)")
            return
        }
        
        log(debug: "Download location available (\(item)): \(location)")
        
        delegate?.downloadLocationAvailable(item, location: location)
    }
    
    func urlSession(
        _ session: URLSession,
        aggregateAssetDownloadTask task: AVAggregateAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange,
        for mediaSelection: AVMediaSelection
    ) {
        var percentComplete = 0.0
        var loadedTimeRangeSeconds = 0.0
        var timeRangeExpectedToLoadSeconds = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            loadedTimeRangeSeconds += CMTimeGetSeconds(loadedTimeRange.duration)
            timeRangeExpectedToLoadSeconds += CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
            percentComplete += loadedTimeRangeSeconds/timeRangeExpectedToLoadSeconds
        }
        
        // "Bytes" are only available if the download has not been paused,
        // so we are using "seconds" instead, which are always available.
        // Total download size will be calculated after the download is completed.
        let downloadedBytes = Int(loadedTimeRangeSeconds)
        let totalBytes = Int(timeRangeExpectedToLoadSeconds)
        
        guard let item = item(for: task) else {
            // Not found
            return
        }
        
        log(debug: "Download progress for \(item): \(Int(percentComplete * 100))%")
        
        // Notify change state
        delegate?.downloadProgress(item, loaded: downloadedBytes, total: totalBytes)
    }
}

private enum AssetDownloaderError: Error {
    case simulatorNotSupported
    case drmNotSupported
    case ckc
    case unknown
}
