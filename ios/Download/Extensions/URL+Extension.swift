//
//  URL+extension.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 21/11/24.
//

import Foundation

extension URL {
    var queryDictionary: [String: String]? {
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
        .queryItems?.reduce(into: [String: String]()) {
            $0[$1.name] = $1.value
        }
    }

    init?(string: String?) {
        guard let string = string else {
            return nil
        }
        self.init(string: string)
    }

    func appending(_ queryItem: String, value: String?) -> URL {

       guard var urlComponents = URLComponents(string: absoluteString) else { return absoluteURL }

       // Create array of existing query items
       var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []

       // Create query item
       let queryItem = URLQueryItem(name: queryItem, value: value)

       // Append the new query item in the existing query items array
       queryItems.append(queryItem)

       // Append updated query items array in the url component object
       urlComponents.queryItems = queryItems

       // Returns the url from new url components
       return urlComponents.url!
   }
    
    var calculateSize: Float? {
        let properties: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
        ]
        
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: relativePath),
            includingPropertiesForKeys: properties,
            options: .skipsHiddenFiles,
            errorHandler: nil
        ) else {
            return nil
        }
        
        let urls: [URL] = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.absoluteString.contains(".frag") }
        
        let regularFileResources: [URLResourceValues] = urls
            .compactMap { try? $0.resourceValues(forKeys: Set(properties)) }
            .filter { $0.isRegularFile == true }
        
        let sizes: [Int64] = regularFileResources
            .compactMap { $0.totalFileAllocatedSize }
            .compactMap { Int64($0) }
        
        let raw = sizes.reduce(0, +)
        let mb = raw / (1024 * 1024)
        
        return Float(mb)
    }
}
