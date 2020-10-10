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

public class Statement {
    
    unowned public let database: Database;
    public let statement: SQLStatement;
    
    public var parametersCount: Int {
        return Int(sqlite3_bind_parameter_count(statement));
    }
    
    public init(database: Database, query: String) throws {
        var handle: OpaquePointer? = nil;
        let code = sqlite3_prepare_v2(database.connection, query, -1, &handle, nil);
        guard code == SQLITE_OK, let openedHandle = handle else {
            throw DBError(database: database, resultCode: code) ?? DBError.internalError;
        }
        self.database = database;
        self.statement = openedHandle;
    }
    
    deinit {
        sqlite3_finalize(statement);
    }
    
    public func query(_ params: [String: Any?]) throws -> Cursor {
        try self.prepare(params);
        return Cursor(database: database, statement: self);
    }

    public func query(_ params: [Any?] = []) throws -> Cursor {
        try self.prepare(params);
        return Cursor(database: database, statement: self);
    }

    public func execute(_ params: [String: Any?]) throws {
        try self.prepare(params);
        let code = sqlite3_step(statement);
        guard code == SQLITE_DONE else {
            throw DBError(database: database, resultCode: code) ?? DBError.internalError;
        }
    }
    
    public func execute(_ params: [Any?] = []) throws {
        try self.prepare(params);
        let code = sqlite3_step(statement);
        guard code == SQLITE_DONE else {
            throw DBError(database: database, resultCode: code) ?? DBError.internalError;
        }
    }

    
    private func prepare(_ params: [String: Any?]) throws {
        try bind(params: params);
        try reset(bindings: false);
    }

    private func prepare(_ params: [Any?]) throws {
        try bind(params: params);
        try reset(bindings: false);
    }

    private func bind(params: [String: Any?]) throws {
        try reset();
        for (name,value) in params {
            let position = sqlite3_bind_parameter_index(statement, ":\(name)");
            guard position != 0 || parametersCount == 0  else {
                throw DBError.invalidParameterName(name: name);
            }
            try bind(value, at: position);
        }
    }
    
    private func bind(params: [Any?]) throws {
        try reset();
        for position in 0..<params.count {
            try bind(params[position], at: Int32(position) + 1);
        }
    }
    
    private func bind(_ v: Any?, at pos: Int32) throws {
        var r:Int32 = SQLITE_OK;
        guard let value = v else {
            r = sqlite3_bind_null(statement, pos);
            if let error = DBError(database: database, resultCode: r) {
                throw error;
            }
            return;
        }
        
        switch value {
        case let v as [UInt8]:
            r = sqlite3_bind_blob(statement, pos, v, Int32(v.count), SQLITE_TRANSIENT);
        case let v as Data:
            r = v.withUnsafeBytes { (bytes) -> Int32 in
                return sqlite3_bind_blob(statement, pos, bytes.baseAddress!, Int32(v.count), SQLITE_TRANSIENT);
            }
        case let v as Double:
            r = sqlite3_bind_double(statement, pos, v);
        case let v as UInt32:
            r = sqlite3_bind_int(statement, pos, Int32(bitPattern: v));
        case let v as Int32:
            r = sqlite3_bind_int(statement, pos, v);
        case let v as Int:
            r = sqlite3_bind_int64(statement, pos, Int64(v));
        case let v as Bool:
            r = sqlite3_bind_int(statement, pos, Int32(v ? 1 : 0));
        case let v as String:
            r = sqlite3_bind_text(statement, pos, v, -1, SQLITE_TRANSIENT);
        case let v as Date:
            let timestamp = Int64(v.timeIntervalSince1970 * 1000);
            r = sqlite3_bind_int64(statement, pos, timestamp);
        case let v as DatabaseConvertibleStringValue:
            try self.bind(v.encode(), at: pos);
        case let v as DatabaseConvertibleIntValue:
            try self.bind(v.encode(), at: pos);
        case let v as DatabaseConvertibleDataValue:
            try self.bind(v.encode(), at: pos);
        default:
            throw DBError.unsupportedType(name: v.self.debugDescription)
        }
        if let error = DBError(database: database, resultCode: r) {
            throw error;
        }
    }
    
    func reset(bindings: Bool = true) throws {
        if let error = DBError(resultCode: sqlite3_reset(statement)) {
            throw error;
        }
        if bindings {
            if let error = DBError(resultCode: sqlite3_clear_bindings(statement)) {
                throw error;
            }
        }
    }
    
}
