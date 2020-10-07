//
// Database.swift
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

import Foundation
import CSQLite

public typealias SQLConnection = OpaquePointer;

public class Database: DatabaseWriter {
    public let connection: SQLConnection;
    
    lazy var statementsCache = StatementCache(database: self);
    
    public var errorMessage: String? {
        if let tmp = sqlite3_errmsg(connection) {
            return String(cString: tmp);
        }
        return nil;
    }
    
    public var lastInsertedRowId: Int? {
        return Int(sqlite3_last_insert_rowid(connection));
    }
    
    public init (path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX) throws {
        var handle: OpaquePointer? = nil;
        let code = sqlite3_open_v2(path, &handle, flags, nil);
        guard code == SQLITE_OK, let openedHandle = handle else {
            sqlite3_close_v2(handle);
            throw DBError(resultCode: code) ?? DBError.internalError;
        }
        self.connection = openedHandle;
    }
    
    deinit {
        statementsCache.invalidate();
        let result = sqlite3_close_v2(connection);
    }
    
    public func freeMemory() {
        statementsCache.invalidate();
    }
    
}

extension Database {
    
    public func execute(query: String) throws {
        try createStatement(query: query).execute();
    }
    
}
