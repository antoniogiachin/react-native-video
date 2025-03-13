//
//  AssetDownloader.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import UIKit
import AVFoundation

protocol AssetDownloaderDelegate: NSObjectProtocol {
    func downloadStateChanged(_ info: DownloadInfo, state: DownloadState)
    func downloadProgress(_ info: DownloadInfo, loaded: Int, total: Int)
    func downloadError(_ info: DownloadInfo, error: Error)
    func downloadLocationAvailable(_ info: DownloadInfo, location: URL)
    func downloadCkcAvailable(_ info: DownloadInfo, ckc: Data)
}

class AssetDownloader: NSObject {
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
    private var downloading: [DownloadInfo] = []
    
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
    
    func resume(_ info: DownloadInfo) {
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
    
    func renew(_ info: DownloadInfo, completion: ((Result<Data, Error>) -> Void)? = nil) {
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
            debugPrint("ASSET DOWNLOADER: Cancelled download of \(item.identifier)")
        }
    }
    
    /// Start the download task.
    private func start(_ info: DownloadInfo) {
        let asset = info.asset
        
        debugPrint("ASSET DOWNLOADER: Starting download of \(info.identifier)")
        
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
        downloading.append(info)
        
        // Notify change state
        delegate?.downloadStateChanged(info, state: .downloading)
        
        // Limiting the number of simultaneous downloads
        queue.async { [weak self] in
            self?.semaphore.wait()
            task.resume()
        }
    }
    
    private func calculateMedianBitrate(bitrates: [Double]) -> Double? {
        guard !bitrates.isEmpty else { return nil }
        
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
    private func item(for task: URLSessionTask) -> DownloadInfo? {
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
        
        // Cleanup the downloading list
        downloading.remove { $0 == item }
        
        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                debugPrint("ASSET DOWNLOADER: Download was cancelled")
                
                /*
                 This task was canceled, you should perform cleanup using the
                 URL saved from AVAssetDownloadDelegate.urlSession(_:assetDownloadTask:didFinishDownloadingTo:).
                 */
                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                delegate?.downloadError(item, error: error)
                
            default:
                debugPrint("ASSET DOWNLOADER: An unexpected error occured \(error)")
                
#if targetEnvironment(simulator)
                delegate?.downloadError(item, error: AssetDownloaderError.simulatorNotSupported)
#else
                delegate?.downloadError(item, error: error)
#endif
            }
        } else {
            debugPrint("ASSET DOWNLOADER: Downloading completed with success")
            delegate?.downloadStateChanged(item, state: .completed)
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
        let percentage = Int(task.progress.fractionCompleted * 100)
        debugPrint("ASSET DOWNLOADER downloaded \(percentage)%")
        
        let downloadedBytes = Int(task.progress.completedUnitCount)
        let totalBytes = Int(task.progress.totalUnitCount)
        
        guard let item = item(for: task), percentage > 0 else {
            // Not found
            return
        }
        
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
