import Foundation

public protocol RedisValue : CustomStringConvertible {
    var redisText: [UInt8] { get }
}

extension String : RedisValue {
    public var redisText: [UInt8] {
        let utf8 = [UInt8](self.utf8)
        
        return [SpecialCharacters.dollar] + [UInt8](utf8.count.description.utf8) + EOL + utf8 + EOL
    }

    public var simpleString: SimpleString {
        return SimpleString([UInt8](self.utf8))
    }
}

public struct SimpleString : RedisValue {
    public var description: String {
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    var bytes: [UInt8]
    
    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var redisText: [UInt8] {
        return [SpecialCharacters.plus] + bytes + EOL
    }
}

internal let EOL: [UInt8] = [0x0D, 0x0A]

public enum SpecialCharacters {
    public static let dollar: UInt8 = 0x24
    public static let asterisk: UInt8 = 0x2a
    public static let plus: UInt8 = 0x2b
    public static let minus: UInt8 = 0x2d
    public static let one: UInt8 = 0x31
    public static let colon: UInt8 = 0x3a

    public static let carriageReturn: UInt8 = 0x0D
}

extension Array : RedisValue {
    public var redisText: [UInt8] {
        let values = self.flatMap {
            ($0 as? RedisValue)?.redisText
        }
        
        return [SpecialCharacters.asterisk] + [UInt8](values.count.description.utf8) + EOL + values.reduce([], +)
    }
}

extension Int : RedisValue {
    public var redisText: [UInt8] {
        return [SpecialCharacters.colon] + [UInt8](self.description.utf8) + EOL
    }
}

extension Int {
    init(byteString: [UInt8]) throws {
        var byteString = byteString

        var me = 0
        var power = 1
        var minus = false

        guard byteString.count > 0 else {
            throw RedisError("DRIVER Invalid integer")
        }

        if byteString[0] == SpecialCharacters.minus {
            guard byteString.count > 1 else {
                throw RedisError("DRIVER Invalid integer")
            }

            byteString.removeFirst()
            
            minus = true
        }
        
        for byte in byteString.reversed() {
            defer { power = power * 10 }
            
            guard byte >= 0x30 && byte <= 0x39 else {
                throw RedisError("DRIVER Invalid integer")
            }
            
            let byte = byte - 0x30
            
            me += Int(byte) * power
        }
        
        if minus {
            self = -me
        } else {
            self = me
        }
    }
}

public struct RedisError : Swift.Error, RedisValue {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        return message
    }
    
    public var redisText: [UInt8] {
        return [SpecialCharacters.minus] + [UInt8](self.message.utf8) + EOL
    }
}

extension NSNull : RedisValue {
    public var redisText: [UInt8] {
        return [SpecialCharacters.dollar, SpecialCharacters.minus, SpecialCharacters.one] + EOL
    }
}
