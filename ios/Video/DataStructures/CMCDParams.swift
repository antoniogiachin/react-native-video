import Foundation

struct CMCDParams {
    let cmcdObject: [(String, Any)]
    let cmcdRequest: [(String, Any)]
    let cmcdSession: [(String, Any)]
    let cmcdStatus: [(String, Any)]
    let mode: Int

    init(
        cmcdObject: [(String, Any)] = [],
        cmcdRequest: [(String, Any)] = [],
        cmcdSession: [(String, Any)] = [],
        cmcdStatus: [(String, Any)] = [],
        mode: Int = 1
    ) {
        self.cmcdObject = cmcdObject
        self.cmcdRequest = cmcdRequest
        self.cmcdSession = cmcdSession
        self.cmcdStatus = cmcdStatus
        self.mode = mode
    }

    static func parse(from dict: NSDictionary?) -> CMCDParams? {
        guard let dict = dict else { return nil }

        return CMCDParams(
            cmcdObject: parseKeyValuePairs(from: dict["object"] as? [[String: Any]]),
            cmcdRequest: parseKeyValuePairs(from: dict["request"] as? [[String: Any]]),
            cmcdSession: parseKeyValuePairs(from: dict["session"] as? [[String: Any]]),
            cmcdStatus: parseKeyValuePairs(from: dict["status"] as? [[String: Any]]),
            mode: dict["mode"] as? Int ?? 1
        )
    }

    private static func parseKeyValuePairs(from array: [[String: Any]]?) -> [(String, Any)] {
        guard let array = array else { return [] }

        return array.compactMap { item in
            guard let key = item["key"] as? String else { return nil }

            let value: Any?
            if let numberValue = item["value"] as? NSNumber {
                value = numberValue
            } else if let stringValue = item["value"] as? String {
                value = stringValue
            } else {
                value = nil
            }

            return value != nil ? (key, value!) : nil
        }
    }
}
