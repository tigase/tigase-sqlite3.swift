//
// DatabaseWriter+Query.swift
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

extension DatabaseWriter {
    
    public func delete(query: Query, cached: Bool = true, params: [String: Any?]) throws {
        try delete(query.statement, cached: cached, params: params);
    }

    public func delete(query: Query, cached: Bool = true, params: [Any?] = []) throws {
        try delete(query.statement, cached: cached, params: params);
    }

    public func insert(query: Query, cached: Bool = true, params: [String: Any?]) throws {
        try insert(query.statement, cached: cached, params: params);
    }

    public func insert(query: Query, cached: Bool = true, params: [Any?] = []) throws {
        try insert(query.statement, cached: cached, params: params);
    }
    
    public func update(query: Query, cached: Bool = true, params: [String: Any?]) throws {
        try update(query.statement, cached: cached, params: params);
    }

    public func update(query: Query, cached: Bool = true, params: [Any?] = []) throws {
        try update(query.statement, cached: cached, params: params);
    }

    public func execute(query: Query, params: [String: Any?]) throws {
        try execute(query.statement, params: params);
    }

    public func execute(query: Query, params: [Any?] = []) throws {
        try execute(query.statement, params: params);
    }

}
