import Foundation
import MistportServer

let configuration = ServerConfiguration.fromEnvironment()
print("mistport-server: database \(configuration.databasePath), listening on \(configuration.host):\(configuration.port), admin routes \(configuration.adminToken == nil ? "off" : "on")")
try await buildApplication(configuration).runService()
