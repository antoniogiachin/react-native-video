//
//  CustomError.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class CustomError {
    
    public class func build(code: Int = 500, failureReason: String?) -> NSError {
        let errorDomain = "it.rai.error"
        var userInfo : [String:String] = [:]
        if let failureReason = failureReason {
            userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
        }
        return NSError(domain: errorDomain, code: code, userInfo: userInfo)
    }
}



public extension NSError {
    func errorDescription() -> String?{
        return self.userInfo[NSLocalizedFailureReasonErrorKey] as? String
    }
}
