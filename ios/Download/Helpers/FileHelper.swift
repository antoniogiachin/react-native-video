//
//  FileHelper.swift
//  react-native-video
//
//  Created by Davide Balistreri on 24/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

class FileHelper: DownloadLogging {
    static var shared = FileHelper()
    
    private let fileManager = FileManager.default
    
    /// Subfolder where the media files are stored, each content will have a subfolder with its content id.
    private let MEDIA_CACHE_KEY = "media_cache"
    
    /// Saves given data to the user's document directory, returning its file path.
    func save(
        _ data: Data,
        in directory: String,
        subdirectory: String? = nil,
        fileName: String
    ) throws -> String {
        var fileUrl = try contentSubfolder(directory)
        
        if let subdirectory {
            fileUrl = fileUrl
                .appendingPathComponent(subdirectory, isDirectory: true)
        }
        
        fileUrl = try fileUrl
            .creatingDirectoryIfNeeded()
            .appendingPathComponent(fileName)
        
        // Write the data
        try data.write(to: fileUrl)
        
        return fileUrl.path
    }
    
    func delete(_ download: DownloadModel) throws {
        if let url = download.location {
            // Delete video assets
            try fileManager.removeItem(at: url)
        }
        
        // Delete thumbnails and subtitles
        let subfolder = try contentSubfolder(download.identifier)
        try fileManager.removeItem(at: subfolder)
    }
    
    private func composeBasePath() throws -> URL {
        // User document directory
        guard let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw NSError(domain: "ImageHelper", code: 1, userInfo: nil)
        }
        
        return documents
            .appendingPathComponent(MEDIA_CACHE_KEY, isDirectory: true)
    }
    
    private func contentSubfolder(_ identifier: String) throws -> URL {
        try composeBasePath()
            .appendingPathComponent(identifier, isDirectory: true)
    }
}

fileprivate extension URL {
    @discardableResult
    func creatingDirectoryIfNeeded() throws -> URL {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: self.path) {
            try fileManager.createDirectory(
                at: self,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return self
    }
}
