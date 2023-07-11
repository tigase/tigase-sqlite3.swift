//
// SQLCodable+Query.swift
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
import SQLite3

extension SQLCodable {
    
    public static func findAll(in database: DatabaseReader, where query: ModelQueryExpression<Self>? = nil, orderBy: [OrderClause<Self>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil, withRelations: Bool) throws -> [Self] {
        let items: [Self] = try database.select(where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
        if withRelations && !items.isEmpty {
            try loadRelations(from: database, for: items);
        }
        return items;
    }

    public static func findFirst(in database: DatabaseReader, where query: ModelQueryExpression<Self>? = nil, orderBy: [OrderClause<Self>]? = nil, indexedBy: String? = nil, withRelations: Bool) throws -> Self? {
        let items: [Self] = try database.select(where: query, orderBy: orderBy, limit: .limit(1), indexedBy: indexedBy);
        if withRelations && !items.isEmpty {
            try loadRelations(from: database, for: items);
        }
        return items.first;
    }
    
    public static func select(from database: DatabaseReader, where query: ModelQueryExpression<Self>? = nil, orderBy: [OrderClause<Self>]? = nil, indexedBy: String? = nil) throws -> [ModelRow<Self>] {
        return try database.select(where: query, orderBy: orderBy, indexedBy: indexedBy);
    }
    
    public static func delete(from database: DatabaseWriter, where query: ModelQueryExpression<Self>?) throws {
        return try database.delete(Self.self, where: query);
    }
    
    public static func update(in database: DatabaseWriter, set: [ModelUpdateExpression<Self>], where query: ModelQueryExpression<Self>?) throws {
        return try database.update(Self.self, set: set, where: query);
    }

    public init(row: Row) {
        self.init(model: ModelRow(row: row));
    }
}

