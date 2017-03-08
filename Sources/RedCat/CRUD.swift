extension RedCat {
    public func setValue(to value: RedisValue, for key: String) throws {
        try handleOK(try send(["SET", key, value.description]))
    }
    
    public func get(keys key: String, _ keys: String...) throws -> [RedisValue] {
        return try get(keys: [key] + keys)
    }
    
    public func get(keys: [String]) throws -> [RedisValue] {
        let command: [RedisValue] = ["MGET"] + keys
        
        guard let results = try handleError(try send(command)) as? [RedisValue] else {
            throw RedisError("DRIVER Unexpected response")
        }
        
        return results
    }
    
    public func updateValue(_ value: RedisValue, forKey key: String) throws {
        try handleOK(try send(["SET", key, value.description]))
    }
    
    public func get(key: String) throws -> RedisValue {
        return try handleError(try send(["GET", key]))
    }
    
    public func removeValue(forKey key: String) throws {
        try removeValue(forKeys: key)
    }
    
    @discardableResult
    public func removeValue(forKeys keys: String...) throws -> Int {
        let response = try send(["DEL"] + keys)
        
        guard let removedCount = response as? Int else {
            throw (response as? RedisError) ?? RedisError("DRIVER Unknown error")
        }
        
        return removedCount
    }
    
    public func listKeys(pattern: String = "*") throws -> [String] {
        let response = try send(["KEYS", pattern])
        
        return (response as? Array ?? []).flatMap {
            $0 as? String
        }
    }
}
