//
// Statement.swift
//
// TigaseSQLite3.swift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//
//

import Foundation
import CSQLite

public let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public typealias SQLStatement = OpaquePointer;

final class Statement {
    
    private let connection: SQLConnection;
    private let statement: SQLStatement;
    
    private var parametersCount: Int {
        return Int(sqlite3_bind_parameter_count(statement));
    }
    
    public init(connection: SQLConnection, query: String) throws {
        var handle: OpaquePointer? = nil;
        let code = sqlite3_prepare_v2(connection, query, -1, &handle, nil);
        guard code == SQLITE_OK, let openedHandle = handle else {
            throw DBError(connection: connection, resultCode: code) ?? DBError.internalError;
        }
        self.connection = connection;
        self.statement = openedHandle;
    }
    
    deinit {
        sqlite3_finalize(statement);
    }
    
    public func execute(params: [SQLValue]) throws -> [Row] {
        try resetStatement();
        defer {
            resetBindings();
        }
        for position in 0..<params.count {
            try bind(params[position], at: Int32(position) + 1);
        }
        return try processResults();
    }
    
    public func execute(params: [String: SQLValue]) throws -> [Row] {
        try resetStatement();
        defer {
            resetBindings();
        }
        for (name,value) in params {
            let position = sqlite3_bind_parameter_index(statement, ":\(name)");
            guard position != 0 || parametersCount == 0  else {
                throw DBError.invalidParameterName(name: name);
            }
            try bind(value, at: position);
        }
        return try processResults();
    }
    
    private func processResults() throws -> [Row] {
        let columnCount = Int(sqlite3_column_count(statement));
        var results: [Row] = [];
        guard columnCount > 0 else {
            while true {
                switch sqlite3_step(statement) {
                case SQLITE_DONE:
                    return results;
                case let resultCode:
                    throw DBError(connection: connection, resultCode: resultCode)!;
                }
            }
            return results;
        }
        
        let columnNames = (0..<Int32(columnCount)).map({ String(cString: sqlite3_column_name(statement, $0)!) })
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_DONE:
                return results;
            case SQLITE_ROW:
                results.append(processResult(columnNames: columnNames));
            case let resultCode:
                throw DBError(connection: connection, resultCode: resultCode)!;
            }
        }
    }
    
    private func processResult(columnNames: [String]) -> Row {
        var row: Row = [:];
        for (pos,name) in columnNames.enumerated() {
            let idx = Int32(pos);
            switch sqlite3_column_type(statement, idx) {
            case SQLITE_NULL:
                row[name] = .null;
            case SQLITE_INTEGER:
                row[name] = .integer(Int(sqlite3_column_int64(statement, idx)));
            case SQLITE_FLOAT:
                row[name] = .double(sqlite3_column_double(statement, idx));
            case SQLITE_TEXT:
                guard let ptr = sqlite3_column_text(statement, idx) else {
                    continue;
                }
                row[name] = .text(String(cString: UnsafePointer(ptr)));
            case SQLITE_BLOB:
                guard let origPtr = sqlite3_column_blob(statement, idx) else {
                    continue;
                }
                let count = Int(sqlite3_column_bytes(statement, idx));
                row[name] = .blob(Data(bytes: origPtr, count: count));
            default:
                break;
            }
        }
        return row;
    }
    
    private func bind(_ v: SQLValue, at pos: Int32) throws {
        var r:Int32 = SQLITE_OK;
        switch v {
        case .null:
            r = sqlite3_bind_null(statement, pos);
        case .integer(let value):
            r = sqlite3_bind_int64(statement, pos, Int64(value));
        case .double(let value):
            r = sqlite3_bind_double(statement, pos, value);
        case .text(let value):
            r = sqlite3_bind_text(statement, pos, value, -1, SQLITE_TRANSIENT);
        case .blob(let value):
            r = value.withUnsafeBytes { (bytes) -> Int32 in
                return sqlite3_bind_blob(statement, pos, bytes.baseAddress!, Int32(value.count), SQLITE_TRANSIENT);
            }
        }
        if let error = DBError(connection: connection, resultCode: r) {
            throw error;
        }
    }
    
    private func resetBindings() {
        sqlite3_clear_bindings(statement);
    }

    private func resetStatement() throws {
        if let error = DBError(connection: connection, resultCode: sqlite3_reset(statement)) {
            throw error;
        }
    }
    
}

public typealias Row = Dictionary<String,SQLValue>

extension Row {
        
    public subscript<T: SQLCodable, V: Decodable>(_ keyPath: KeyPath<T, V?>) -> V? {
        do {
            return try value(for: keyPath).value()
        } catch {
            fatalError("Failed to decode value: \(error.localizedDescription)")
        }
    }

    public subscript<T: SQLCodable, V: Decodable>(_ keyPath: KeyPath<T, V>) -> V {
        do {
            guard let v: V = try value(for: keyPath).value() else {
                fatalError("No value to decode!");
            }
            return v;
        } catch {
            fatalError("Failed to decode value: \(error.localizedDescription)")
        }
    }

    func value<T: SQLCodable,V>(for keyPath: KeyPath<T,V>) -> Value {
        let name = T.keyPathToColumnName(for: keyPath);
        guard let value = self[name] else {
            fatalError("Value not available for column \(name))");
        }
        return value;
    }
    
    public subscript<V: Decodable>(_ key: String) -> V? {
        do {
            guard let value = self[key] else {
                fatalError("Value not available for column \(key))");
            }
            return try value.value();
        } catch {
            fatalError("Failed to decode value: \(error.localizedDescription)")
        }
    }
    
}
