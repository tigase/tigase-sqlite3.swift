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
    
    func select(_ query: String, cached: Bool, params: [String: Any?]) throws -> Cursor;

    func select(_ query: String, cached: Bool, params: [Any?]) throws -> Cursor;

    func count(_ query: String, cached: Bool, params: [String: Any?]) throws -> Int
    
    func count(_ query: String, cached: Bool, params: [Any?]) throws -> Int
    
}

extension DatabaseReader {
    
    public func select(_ query: String, cached: Bool = true, params: [String: Any?]) throws -> Cursor {
        return try select(query, cached: cached, params: params);
    }

    public func select(_ query: String, cached: Bool = true, params: [Any?] = []) throws -> Cursor {
        return try select(query, cached: cached, params: params);
    }
    
    public func count(_ query: String, cached: Bool = true, params: [String: Any?]) throws -> Int {
        guard let value = try select(query, cached: cached, params: params).first()?.int(at: 0) else {
            throw DBError.invalidResult;
        }
        return value;
    }
    
    public func count(_ query: String, cached: Bool = true, params: [Any?] = []) throws -> Int {
        guard let value = try select(query, cached: cached, params: params).first()?.int(at: 0) else {
            throw DBError.invalidResult;
        }
        return value;
    }
    
}
