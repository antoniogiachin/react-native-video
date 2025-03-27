import Foundation

typealias CMCDParamsTuple = (String, Any)

struct CMCDParams {
    let cmcdObject: [CMCDParamsTuple]
    let cmcdRequest: [CMCDParamsTuple]
    let cmcdSession: [CMCDParamsTuple]
    let cmcdStatus: [CMCDParamsTuple]
    let mode: Int

    init(
        cmcdObject: [CMCDParamsTuple] = [],
        cmcdRequest: [CMCDParamsTuple] = [],
        cmcdSession: [CMCDParamsTuple] = [],
        cmcdStatus: [CMCDParamsTuple] = [],
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

    private static func parseKeyValuePairs(from array: [[String: Any]]?) -> [CMCDParamsTuple] {
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

extension [CMCDParamsTuple] {
    /// Searchs for a key in the tuple array and returns its `String` value.
    func string(for key: String) -> String? {
        value(for: key) as? String
    }
    
    /// Searchs for a key in the tuple array and returns its `Bool` value.
    func bool(for key: String) -> Bool? {
        value(for: key) as? Bool
    }
    
    private func value(for name: String) -> Any? {
        for (key, value) in self {
            if key == name {
                return value
            }
        }
        return nil
    }
}
