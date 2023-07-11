//
// DatabaseReader.swift
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

public protocol DatabaseReader: AnyObject {

    func select(_ query: String, cached: Bool, params: [SQLValue]) throws -> [Row];
    
    func select(_ query: String, cached: Bool, params: [String:SQLValue]) throws -> [Row];
        
}

extension DatabaseReader {
    
    public func select(_ query: String, params: [SQLValue]) throws -> [Row] {
        return try select(query, cached: true, params: params)
    }

    public func select(_ query: String, params: [String:SQLValue]) throws -> [Row] {
        return try select(query, cached: true, params: params)
    }

    public func select(_ query: String, cached: Bool = true, params: [String: Encodable?]) throws -> [Row] {
        return try select(query, cached: cached, params: try params.mapValues(SQLValue.fromAny(_:)));
    }

    public func select(_ query: String, cached: Bool = true, params: [Encodable?] = []) throws -> [Row] {
        return try select(query, cached: cached, params: try params.map(SQLValue.fromAny(_:)));
    }
    
    public func count(_ query: String, cached: Bool = true, params: [String: Encodable?]) throws -> Int {
        guard let value = try select(query, cached: cached, params: params).first?["count"]?.int else {
            throw DBError.invalidResult;
        }
        return value;
    }
    
    public func count(_ query: String, cached: Bool = true, params: [Encodable?] = []) throws -> Int {
        guard let value = try select(query, cached: cached, params: params).first?["count"]?.int else {
            throw DBError.invalidResult;
        }
        return value;
    }
    
}
