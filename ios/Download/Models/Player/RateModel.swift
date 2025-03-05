//
//  RateModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class RateModel {
    public init(label: String, value: Float = 1) {
        self.label = label
        self.value = value
    }
    
    public var label: String
    public var value: Float = 1
}
