//
//  Array+Extension.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

extension Array {
    mutating func remove(where predicate: (Element) -> Bool) {
        self = filter { !predicate($0) }
    }
    
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}
