//
// Cursor.swift
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

public class Cursor {
    
    public let database: Database;
    public let statement: Statement;
    private var isDone: Bool = false;
    
    open lazy var columnCount:Int = Int(sqlite3_column_count(statement.statement));
    
    open lazy var columnNames:[String] = (0..<Int32(columnCount)).map { (idx:Int32) -> String in
        return String(cString: sqlite3_column_name(statement.statement, idx)!);
    }

    init(database: Database, statement: Statement) {
        self.database = database;
        self.statement = statement;
    }
    
    deinit {
        try? statement.reset();
    }
    
    public func next() throws -> Bool {
        guard !isDone else {
            return false;
        }
        switch sqlite3_step(statement.statement) {
        case SQLITE_DONE:
            isDone = true;
            return false;
        case SQLITE_ROW:
            return true;
        case let resultCode:
            throw DBError(database: database, resultCode: resultCode)!;
        }
    }
    
    public func first() throws -> Cursor? {
        guard try next() else {
            return nil;
        }
        return self;
    }
    
    public func forEach(_ fn: (Cursor)->Void) throws {
        while try next() {
            fn(self);
        }
    }
    
    public func mapFirst<T>(_ fn: (Cursor)->T?) throws -> T? {
        guard try next() else {
            return nil;
        }
        return fn(self);
    }
    
    public func mapAll<T>(_ fn: (Cursor)->T?) throws -> [T] {
        var result: [T] = [];
        while try next() {
            if let value = fn(self) {
                result.append(value);
            }
        }
        return result;
    }
    
}
