//
// UpdateExpression.swift
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

protocol UpdateExpression: SQLParameterProvider {
    
}

public struct ModelUpdateExpression<T: SQLCodable>: UpdateExpression {
    
    let expression: UpdateExpression;
        
    public static func `set`<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelUpdateExpression<T> {
        return .init(expression: UpdateColumnExpression(column: keyPath, value: value));
    }

    public static func `set`<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelUpdateExpression<T> {
        return .init(expression: UpdateColumnExpression(column: keyPath, value: value));
    }

    public static func clear<V: Encodable>(_ keyPath: KeyPath<T,V?>) -> ModelUpdateExpression<T> {
        return .init(expression: ClearColumnExpression(column: keyPath));
    }
    
    public static func generated(query: String, params: [SQLValue]) -> ModelUpdateExpression<T> {
        return .init(expression: GeneratedUpdateExpression(query: query, params: params))
    }
    
    public func sqlParams() throws -> [SQLValue] {
        return try expression.sqlParams();
    }
    
    public func sqlQuery() -> String {
        return expression.sqlQuery();
    }
}

public struct GeneratedUpdateExpression: UpdateExpression {
    
    let query: String;
    let params: [SQLValue];
    
    init(query: String, params: [SQLValue]) {
        self.query = query
        self.params = params
    }
    
    public func sqlQuery() -> String {
        return query;
    }
    
    public func sqlParams() throws -> [SQLValue] {
        return params;
    }
    
}

public struct UpdateColumnExpression<T: SQLCodable, V: Encodable>: UpdateExpression {

    let column: PartialKeyPath<T>
    let value: V?;

    public func sqlParams() throws -> [SQLValue] {
        return [try .fromAny(value)];
    }
    
    public func sqlQuery() -> String {
        return "\(T.keyPathToColumnName(for: column)) = ?";
    }
}

public struct ClearColumnExpression<T: SQLCodable>: UpdateExpression {
    
    let column: PartialKeyPath<T>
    
    public func sqlParams() -> [SQLValue] {
        return [];
    }
    
    public func sqlQuery() -> String {
        return "\(T.keyPathToColumnName(for: column)) = null";
    }
}


