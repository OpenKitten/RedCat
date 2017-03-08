//
//  TTL.swift
//  RedCat
//
//  Created by Joannis Orlandos on 08/03/2017.
//
//

extension RedCat {
    public enum Time {
        case milliseconds(Int)
        case seconds(Int)
        case minutes(Int)
        case hours(Int)
        case days(Int)
        case weeks(Int)
    }
    
    /// Returns true if the expiration was successfully applied
    public func expire(_ key: String, atEpoch time: Time) throws -> Bool {
        switch time {
        case .milliseconds(let ms):
            return try handleError(try send(["PEXPIREAT", key, ms.description])) as? Int == 1
        case .seconds(let seconds):
            return try handleError(try send(["EXPIREAT", key, seconds.description])) as? Int == 1
        case .minutes(let minutes):
            return try handleError(try send(["EXPIREAT", key, (minutes * 60).description])) as? Int == 1
        case .hours(let hours):
            return try handleError(try send(["EXPIREAT", key, (hours * 3600).description])) as? Int == 1
        case .days(let days):
            return try handleError(try send(["EXPIREAT", key, (days * 3600 * 24).description])) as? Int == 1
        case .weeks(let weeks):
            return try handleError(try send(["EXPIREAT", key, (weeks * 3600 * 24 * 7).description])) as? Int == 1
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
        case .minutes(let minutes):
            return try handleError(try send(["EXPIREAT", key, (minutes * 60).description])) as? Int == 1
        case .hours(let hours):
            return try handleError(try send(["EXPIREAT", key, (hours * 3600).description])) as? Int == 1
        case .days(let days):
            return try handleError(try send(["EXPIREAT", key, (days * 3600 * 24).description])) as? Int == 1
        case .weeks(let weeks):
            return try handleError(try send(["EXPIREAT", key, (weeks * 3600 * 24 * 7).description])) as? Int == 1
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
}
