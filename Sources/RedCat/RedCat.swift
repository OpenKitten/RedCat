import Socks
import Foundation

public class RedCat {
    let client: TCPClient
    
    public init() throws {
        self.client = try TCPClient(address: .localhost(port: 6379))
    }
    
    public init(hostname: String, port: UInt16) throws {
        self.client = try TCPClient.init(address: .init(hostname: hostname, port: port))
    }
    
    deinit {
        _ = try? send(["QUIT"])
    }
    
    public func setValue(to value: RedisValue, for key: String) throws {
        try handleOK(try send(["SET", key, value.description]))
    }
    
    public func get(_ key: String, _ keys: String...) throws -> [RedisValue] {
        return try get([key] + keys)
    }
    
    public func get(_ keys: [String]) throws -> [RedisValue] {
        let command: [RedisValue] = ["MGET"] + keys
        
        guard let results = try handleError(try send(command)) as? [RedisValue] else {
            throw RedisError("DRIVER Unexpected response")
        }

        return results
    }
    
    public func updateValue(_ value: RedisValue, forKey key: String) throws {
        try handleOK(try send(["SET", key, value.description]))
    }

    public func get(_ key: String) throws -> RedisValue {
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
    
    public func listKeys(_ pattern: String = "*") throws -> [String] {
        let response = try send(["KEYS", pattern])
        
        return (response as? Array ?? []).flatMap {
            $0 as? String
        }
    }
    
    public enum Time {
        case milliseconds(Int)
        case seconds(Int)
    }
    
    /// Returns true if the expiration was successfully applied
    public func expire(_ key: String, atEpoch time: Time) throws -> Bool {
        switch time {
        case .milliseconds(let ms):
            return try handleError(try send(["PEXPIREAT", key, ms])) as? Int == 1
        case .seconds(let s):
            return try handleError(try send(["EXPIREAT", key, s])) as? Int == 1
        }
    }
    
    /// Returns true if the expiration was successfully applied
    @discardableResult
    public func expire(_ key: String, after duration: Time) throws -> Bool {
        switch duration {
        case .milliseconds(let ms):
            return try handleError(try send(["PEXPIRE", key, ms.description])) as? Int == 1
        case .seconds(let s):
            return try handleError(try send(["EXPIRE", key, s.description])) as? Int == 1
        }
    }
    
    /// Will return true if the TTL has been removed
    ///
    /// False means the key does not exist or had no TTL
    @discardableResult
    public func persist(_ key: String) throws -> Bool {
        guard let removedTTL = try handleError(try send(["TTL", key])) as? Int else {
            throw RedisError("DRIVER Invalid persist response returned. Expected Int")
        }

        return removedTTL == 1
    }
    
    /// Will return -1 if there is no TTL
    public func ttl(_ key: String) throws -> Int {
        guard let remainingTTL = try handleError(try send(["TTL", key])) as? Int else {
            throw RedisError("DRIVER Invalid TTL returned. Expected Int")
        }
        
        return remainingTTL
    }

    /// Will return -1 if there is no TTL
    public func pttl(_ key: String) throws -> Int {
        guard let remainingTTL = try handleError(try send(["PTTL", key])) as? Int else {
            throw RedisError("DRIVER Invalid TTL returned. Expected Int")
        }
        
        return remainingTTL
    }
    
    func handleError(_ response: RedisValue) throws -> RedisValue {
        if let error = response as? RedisError {
            throw error
        }

        return response
    }
    
    func handleOK(_ redisResponse: RedisValue) throws {
        guard let responseString = redisResponse as? String, responseString == "OK" else {
            let error = redisResponse as? RedisError
            
            throw error ?? RedisError("DRIVER Unknown Error")
        }
    }
    
    public func send(_ element: RedisValue) throws -> RedisValue {
        var location = 0
        
        try client.send(bytes: element.redisText)
        let bytes = try client.receiveAll()
        
//        print(String(bytes: element.redisText, encoding: .utf8) ?? "")
        
        func parse() throws -> RedisValue {
            func isEOL() throws {
                guard location + 1 < bytes.count, [bytes[location], bytes[location + 1]] == EOL else {
                    throw RedisError("DRIVER String length not terminated with CRLF")
                }
            }

            guard bytes.count > 1 else {
                throw RedisError("NDRIVER o redis value provided")
            }
            
            let identifier = bytes[location]
            location += 1
            
            switch identifier {
            case SpecialCharacters.colon:
                var intBuffer = [UInt8]()
                
                while location < bytes.count, bytes[location] != SpecialCharacters.carriageReturn {
                    defer { location += 1 }
                    
                    intBuffer.append(bytes[location])
                }

                try isEOL()
                location += 2
                
                return try Int(byteString: intBuffer)
            case SpecialCharacters.asterisk:
                var intBuffer = [UInt8]()
                
                while location < bytes.count, bytes[location] != SpecialCharacters.carriageReturn {
                    defer { location += 1 }
                    
                    intBuffer.append(bytes[location])
                }
                
                let size = try Int(byteString: intBuffer)
                try isEOL()
                location += 2

                var values = [RedisValue]()
                
                for i in 0..<size {
                    values.append(try parse())
                }
                
                return values
            case SpecialCharacters.plus:
                var stringBuffer = [UInt8]()
                
                while location < bytes.count, bytes[location] != SpecialCharacters.carriageReturn {
                    defer { location += 1 }

                    stringBuffer.append(bytes[location])
                }
                
                try isEOL()
                
                location += 2

                guard let string = String(bytes: stringBuffer, encoding: .utf8) else {
                    throw RedisError("DRIVER Invalid string UTF-8")
                }
                
                return string
            case SpecialCharacters.dollar:
                var lengthBytes = [UInt8]()
                
                while location < bytes.count, bytes[location] != SpecialCharacters.carriageReturn {
                    defer { location += 1 }

                    lengthBytes.append(bytes[location])
                }
                
                try isEOL()
                
                location += 2
                
                var length = try Int(byteString: lengthBytes)
                
                guard location + length < bytes.count else {
                    throw RedisError("DRIVER Invalid string length - End of buffer")
                }
                
                var stringBuffer = [UInt8]()
                stringBuffer.reserveCapacity(length)

                while length > 0 {
                    defer { length -= 1 }
                    defer { location += 1 }

                    stringBuffer.append(bytes[location])
                }
                
                try isEOL()
                location += 2
                
                guard let string = String(bytes: stringBuffer, encoding: .utf8) else {
                    throw RedisError("DRIVER Invalid string UTF-8")
                }

                return string
            case SpecialCharacters.minus:
                guard bytes.count > 3, Array(bytes[bytes.count - 2..<bytes.count]) == EOL else {
                    throw RedisError("DRIVER Invalid Redis Error response")
                }
                
                var stringBuffer = [UInt8]()
                
                while location < bytes.count, bytes[location] != SpecialCharacters.carriageReturn {
                    defer { location += 1 }
                    
                    stringBuffer.append(bytes[location])
                }
                
                try isEOL()
                location += 2
                
                throw RedisError(String(bytes: stringBuffer, encoding: .utf8) ?? "DRIVER Unknown error")
            default:
                throw RedisError("Invalid redis value type")
            }
        }
        
        return try parse()
    }
}
