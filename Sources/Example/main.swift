import Foundation
import RedCat

let cat = try RedCat()

try cat.removeValue(forKey: "*")
print("\(try cat.listKeys().count) keys")

for i in 0..<100 {
    try cat.setValue(to: i, for: "key\(i)")
}

print("\(try cat.listKeys("key?").count) keys")
print("\(try cat.listKeys("key?0").count) keys")
print("\(try cat.listKeys("key*").count) keys")
print("\(try cat.listKeys().count) keys")

for value in try cat.get("key10", "key20") {
    print(value)
}
