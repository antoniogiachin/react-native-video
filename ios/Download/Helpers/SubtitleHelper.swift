//
//  SubtitleHelper.swift
//  react-native-video
//
//  Created by Davide Balistreri on 24/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

class SubtitleHelper: DownloadLogging {
    static var shared = SubtitleHelper()
    
    private let SUBTITLES_PATH = "subtitles"
    
    /// Downloads a subtitle from the given URL and saves it to the user's document directory, returning its file path.
    func downloadAndSave(
        from url: String,
        in directory: String,
        fileName: String
    ) async throws -> String {
        // Download subtitle data
        let data = try await NetworkRequest(url: url)
            .asyncResponseData()
        
        // Save in file system
        return try save(data, in: directory, fileName: fileName)
    }
    
    /// Saves subtitle data to the user's document directory, returning its file path.
    func save(
        _ data: Data,
        in directory: String,
        fileName: String
    ) throws -> String {
        try FileHelper.shared.save(
            data,
            in: directory,
            subdirectory: SUBTITLES_PATH,
            fileName: fileName
        )
    }
}
