//
// Database+Statements.swift
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

extension Database {
    
    public func createStatement(query: String) throws -> Statement {
        return try Statement(database: self, query: query);
    }
    
    private func statement(_ query: String, cached: Bool) throws -> Statement {
        return cached ? try self.statementsCache.statement(query: query) : try createStatement(query: query);
    }
    
    public func select(_ query: String, cached: Bool = true, params: [String:Any?]) throws -> Cursor {
        let statement = try self.statement(query, cached: cached);
        return try statement.query(params);
    }

    public func select(_ query: String, cached: Bool = true, params: [Any?] = []) throws -> Cursor {
        let statement = try self.statement(query, cached: cached);
        return try statement.query(params);
    }
    
    public func execute(_ query: String, params: [Any?]) throws {
        let statement = try self.statement(query, cached: false);
        try statement.execute(params)
    }
    
    public func execute(_ query: String, params: [String : Any?]) throws {
        let statement = try self.statement(query, cached: false);
        try statement.execute(params)
    }

    public func insert(_ query: String, cached: Bool = true, params: [String: Any?]) throws {
        let statement = try self.statement(query, cached: cached);
        try statement.execute(params)
    }

    public func insert(_ query: String, cached: Bool = true, params: [Any?] = []) throws {
        let statement = try self.statement(query, cached: cached);
        try statement.execute(params)
    }
    
    public func update(_ query: String, cached: Bool = true, params: [String: Any?]) throws {
        let statement = try self.statement(query, cached: cached);
        try statement.execute(params)
    }

    public func update(_ query: String, cached: Bool = true, params: [Any?] = []) throws {
        let statement = try self.statement(query, cached: cached);
        try statement.execute(params)
    }
    
}
