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
        try? client.close()
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
}
