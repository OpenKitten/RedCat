import XCTest
@testable import RedCat

class RedCatTests: XCTestCase {
    func testCRUD() throws {
        let redcat = try RedCat()
        _ = try redcat.send(["FLUSHALL"])

        try redcat.updateValue(10, forKey: "ten")
        try redcat.updateValue(20, forKey: "twenty")
        try redcat.updateValue("+0 00-000-000-00", forKey: "tel")
        
        XCTAssertEqual(try redcat.listKeys().count, 3)
        XCTAssertEqual(try redcat.listKeys("te?").count, 2)
        XCTAssertEqual(try redcat.listKeys("ten").count, 1)
        XCTAssertEqual(try redcat.listKeys("tel").count, 1)
        XCTAssertEqual(try redcat.listKeys("twenty").count, 1)
        XCTAssertEqual(try redcat.listKeys("t*en*").count, 2)
        
        try redcat.removeValue(forKeys: "ten", "twenty")

        XCTAssertEqual(try redcat.listKeys().count, 1)
    }
    
    func testTTL() throws {
        let redcat = try RedCat()
        _ = try redcat.send(["FLUSHALL"])
        
        try redcat.updateValue("sessiontok3n", forKey: "user:joannis")
        
        XCTAssertEqual(try redcat.listKeys("user:joannis").count, 1)
        
        try redcat.expire("user:joannis", after: .seconds(2))
        XCTAssertEqual(try redcat.ttl("user:joannis"), 2)

        try redcat.persist("user:joannis")
        XCTAssertEqual(try redcat.ttl("user:joannis"), 2)
        try redcat.expire("user:joannis", after: .seconds(2))

        sleep(1)
        
        XCTAssertLessThan(try redcat.pttl("user:joannis"), 1000)
        
        sleep(1)
        XCTAssertEqual(try redcat.listKeys("user:joannis").count, 0)
        XCTAssertEqual(try redcat.ttl("user:joannis"), -2)
    }

    static var allTests = [
        ("testCRUD", testCRUD),
    ]
}
