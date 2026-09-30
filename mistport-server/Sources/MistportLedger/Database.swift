import CSQLite
import Foundation

/// A thin SQLite connection. One connection is used by one thread at a time; the ledger
/// guards it with a lock. Several connections (processes or ledgers) may share one file:
/// writes run in `BEGIN IMMEDIATE` transactions, so they are serialised by SQLite itself.
final class Database: @unchecked Sendable {
    enum Value: Equatable, Sendable {
        case int(Int64)
        case text(String)
        case null
    }

    struct Row {
        fileprivate let values: [String: Value]
        func int(_ column: String) -> Int64 {
            if case .int(let v) = values[column] { return v }
            return 0
        }
        func text(_ column: String) -> String? {
            if case .text(let v) = values[column] { return v }
            return nil
        }
        func string(_ column: String) -> String { text(column) ?? "" }
    }

    struct Failure: Error, CustomStringConvertible {
        let code: Int32
        let message: String
        var description: String { "SQLite \(code): \(message)" }
    }

    private let handle: OpaquePointer
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let db { sqlite3_close(db) }
            throw Failure(code: -1, message: message)
        }
        handle = db
        sqlite3_busy_timeout(handle, 10_000)
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = FULL")
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "exec failed"
            sqlite3_free(error)
            throw Failure(code: code, message: message)
        }
    }

    @discardableResult
    func run(_ sql: String, _ parameters: [Value] = []) throws -> Int {
        _ = try query(sql, parameters)
        return Int(sqlite3_changes(handle))
    }

    func query(_ sql: String, _ parameters: [Value] = []) throws -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw Failure(code: sqlite3_errcode(handle), message: String(cString: sqlite3_errmsg(handle)) + " in " + sql)
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in parameters.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .int(let v): sqlite3_bind_int64(statement, position, v)
            case .text(let v): sqlite3_bind_text(statement, position, v, -1, Self.transient)
            case .null: sqlite3_bind_null(statement, position)
            }
        }
        var rows: [Row] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else {
                throw Failure(code: code, message: String(cString: sqlite3_errmsg(handle)) + " in " + sql)
            }
            var values: [String: Value] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: values[name] = .int(sqlite3_column_int64(statement, column))
                case SQLITE_TEXT: values[name] = .text(String(cString: sqlite3_column_text(statement, column)))
                default: values[name] = .null
                }
            }
            rows.append(Row(values: values))
        }
        return rows
    }

    /// Runs `body` in one write transaction; any thrown error rolls everything back.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// A nested savepoint: rolls back only the work inside `body` if it throws.
    func savepoint<T>(_ body: () throws -> T) throws -> T {
        try execute("SAVEPOINT step")
        do {
            let result = try body()
            try execute("RELEASE step")
            return result
        } catch {
            try? execute("ROLLBACK TO step")
            try? execute("RELEASE step")
            throw error
        }
    }
}
