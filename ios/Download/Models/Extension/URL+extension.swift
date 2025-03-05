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

    public init?(string: String?) {
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
}
