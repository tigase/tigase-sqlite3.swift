//
// DatabaseWriter+Internal.swift
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
import Combine

protocol DatabaseWriterInternal: DatabaseWriter {
    
    func writeInternal<R>(_ block: (DatabaseWriter) throws -> R) rethrows -> R;
    
}

extension DatabaseWriterInternal {
    
    public var changesCount: Int {
        return writeInternal({ writer in
            return writer.changesCount;
        })
    }
    
    public var lastInsertedId: Int {
        return writeInternal({ writer in
            return writer.lastInsertedId;
        })
    }
    
    public func changePublisher(for tableName: String) -> AnyPublisher<Change, Never> {
        return writeInternal({ core in
            return core.changePublisher(for: tableName);
        })
    }
    
    public func withTransaction<R>(_ block: (DatabaseWriter) throws -> R) throws -> R {
        try writeInternal({ core in
            try core.withTransaction(block);
        })
    }
    
    public func insert(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try writeInternal({ core in
            try core.insert(query, cached: cached, params: params);
        })
    }
    
    
    public func insert(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try writeInternal({ core in
            try core.insert(query, cached: cached, params: params);
        })
    }
    
    
    public func update(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try writeInternal({ core in
            try core.update(query, cached: cached, params: params);
        })
    }
    
    
    public func update(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try writeInternal({ core in
            try core.update(query, cached: cached, params: params);
        })
    }
    
    public func delete(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try writeInternal({ core in
            try core.delete(query, cached: cached, params: params);
        })
    }
    
    
    public func delete(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try writeInternal({ core in
            try core.delete(query, cached: cached, params: params);
        })
    }
    
}
