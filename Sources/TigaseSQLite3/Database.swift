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
import Combine

public class Database: DatabaseReaderInternal, DatabaseWriterInternal {
 
    public struct Options: OptionSet {
        
        static let wal = Options(rawValue: 1 << 0)
        
        public var rawValue: UInt;

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    private let lock = UnfairLock();
    private let core: DatabaseCore;
    
    public init(path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, options: Options = []) throws {
        core = try DatabaseCore(path: path, flags: flags, options: options);
    }
    
    func readInternal<R>(_ block: (DatabaseReader) throws -> R) rethrows -> R {
        return try lock.with({
            return try block(core);
        })
    }
    
    func writeInternal<R>(_ block: (DatabaseWriter) throws -> R) rethrows -> R {
        return try lock.with({
            return try block(core);
        })
    }

    public func execute(_ query: String) throws {
        try writeInternal({ writer in
            try writer.execute(query);
        })
    }
    
}
