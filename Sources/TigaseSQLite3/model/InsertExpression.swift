//
// InsertExpression.swift
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

protocol InsertExpression: SQLParameterProvider {
    
}


public struct ModelInsertExpression<T: SQLCodable>: InsertExpression {
    
    public static func value<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelInsertExpression<T> {
        return .init(expression: InsertColumnExpression(column: keyPath, value: value));
    }

    public static func value<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V?) -> ModelInsertExpression<T> {
        return .init(expression: InsertColumnExpression(column: keyPath, value: value));
    }

    let expression: InsertExpression;
    
    public func sqlParams() throws -> [SQLValue] {
        return try expression.sqlParams();
    }
    
    public func sqlQuery() -> String {
        return expression.sqlQuery();
    }
    
}

public struct InsertColumnExpression<T: SQLCodable,V: Encodable>: InsertExpression {
    
    let column: PartialKeyPath<T>
    let value: V?
    
    public func sqlParams() throws -> [SQLValue] {
        return [try SQLValue.fromAny(value)];
    }
    
    public func sqlQuery() -> String {
        return "\(T.keyPathToColumnName(for: column))";
    }
    
}

