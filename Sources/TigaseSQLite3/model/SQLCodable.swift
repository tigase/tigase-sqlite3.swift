//
// SQLCodable.swift
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

public protocol SQLCodable: Codable {
    
    static var tableName: String { get }
    
    static var fields: [SQLField<Self>] { get }
        
    init(model: ModelRow<Self>)
    
    static func loadRelations(from database: DatabaseReader, for items: [Self]) throws
    static var relationTables: [String] { get }

}

extension SQLCodable {
    
    public static func keyPathToColumnName(for keyPath: PartialKeyPath<Self>) -> String {
        return SQLCodableMapper.mapping(for: keyPath);
    }
    
}

public struct SQLField<T: SQLCodable> {
    
    public let keyPath: PartialKeyPath<T>;
    public let column: String;

    public init<V: Decodable>(_ keyPath: KeyPath<T,V?>, column: String) {
        self.keyPath = keyPath;
        self.column = column;
    }
    
    public init<V: Decodable>(_ keyPath: KeyPath<T,V>, column: String) {
        self.keyPath = keyPath;
        self.column = column;
    }
    
    public static func field<V: Decodable>(_ keyPath: WritableKeyPath<T,V>, column: String) -> SQLField<T> {
        return .init(keyPath, column: column);
    }
}


public protocol SQLQueryProvider {
    
    func sqlQuery() -> String;
    
}

public protocol SQLParameterProvider: SQLQueryProvider {
    
    func sqlParams() throws -> [SQLValue];
    
}
