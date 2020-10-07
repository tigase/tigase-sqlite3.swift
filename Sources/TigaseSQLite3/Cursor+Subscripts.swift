//
// Cursor+Subscripts.swift
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

extension Cursor {
    
    public subscript(index: Int) -> Double {
        return sqlite3_column_double(statement.statement, Int32(index));
    }
    
    public subscript(index: Int) -> Int {
        return Int(sqlite3_column_int64(statement.statement, Int32(index)));
    }
    
    public subscript(index: Int) -> Int32 {
        return sqlite3_column_int(statement.statement, Int32(index));
    }
    
    public subscript(index: Int) -> String? {
        let ptr = sqlite3_column_text(statement.statement, Int32(index));
        if ptr == nil {
            return nil;
        }
        return String(cString: UnsafePointer(ptr!));
    }
    
    public subscript(index: Int) -> Bool {
        return sqlite3_column_int64(statement.statement, Int32(index)) != 0;
    }
    
    public subscript(index: Int) -> [UInt8]? {
        let idx = Int32(index);
        let origPtr = sqlite3_column_blob(statement.statement, idx);
        if origPtr == nil {
            return nil;
        }
        let count = Int(sqlite3_column_bytes(statement.statement, idx));
        let ptr = origPtr?.assumingMemoryBound(to: UInt8.self)
        return Cursor.convert(count, data: ptr!);
    }
    
    public subscript(index: Int) -> Data? {
        let idx = Int32(index);
        let origPtr = sqlite3_column_blob(statement.statement, idx);
        if origPtr == nil {
            return nil;
        }
        let count = Int(sqlite3_column_bytes(statement.statement, idx));
        return Data(bytes: origPtr!, count: count);
    }
    
    public subscript(index: Int) -> Date? {
        let value = sqlite3_column_int64(statement.statement, Int32(index));
        guard value != 0 else {
            return nil;
        }
        let timestamp = Double(value) / 1000;
        return Date(timeIntervalSince1970: timestamp);
    }

    public subscript(column: String) -> Double {
        return forColumn(column) {
            return self[$0];
        } ?? 0.0;
    }
    
    public subscript(column: String) -> Int {
        if let idx = columnNames.firstIndex(of: column) {
            return self[idx];
        }
        return 0;
    }
    
    public subscript(column: String) -> String? {
        return forColumn(column) {
            return self[$0];
        }
    }
    
    public subscript(column: String) -> Bool {
        return forColumn(column) {
            return self[$0];
        } ?? false;
    }
    
    public subscript(column: String) -> [UInt8]? {
        return forColumn(column) {
            return self[$0];
        }
    }
    
    public subscript(column: String) -> Data? {
        return forColumn(column) {
            return self[$0];
        }
    }
    
    public subscript(column: String) -> Date? {
        return forColumn(column) {
            return self[$0];
        }
    }

    private static func convert<T>(_ count: Int, data: UnsafePointer<T>) -> [T] {
        let buffer = UnsafeBufferPointer(start: data, count: count);
        return Array(buffer)
    }

    private func forColumn<T>(_ column:String, exec:(Int)->T?) -> T? {
        if let idx = columnNames.firstIndex(of: column) {
            return exec(idx);
        }
        return nil;
    }

}
