//
//  Keys.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

extension UserDefaults: DownloadLogging {
    private enum Keys {
        static let downloads = "downloads"
    }
    
    func setDownloads(_ downloads: [DownloadModel]) {
        do {
            let encoded = try JSONEncoder().encode(downloads)
            set(encoded, forKey: Keys.downloads)
            synchronize()
            log(verbose: "Downloads data saved")
        } catch {
            log(error: "\(error.localizedDescription)")
        }
    }
    
    func getDownloads() -> [DownloadModel]? {
        log(verbose: "Loading saved downloads data")
        
        guard let savedData = data(forKey: Keys.downloads) else {
            log(verbose: "No saved downloads data available")
            return nil
        }
        
        do {
            return try JSONDecoder().decode([DownloadModel].self, from: savedData)
        } catch {
            log(error: "\(error.localizedDescription)")
            return nil
        }
    }
}
