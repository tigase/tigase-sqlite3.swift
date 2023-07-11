//
// QueryExpression.swift
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

public protocol QueryExpression: SQLParameterProvider {
    
    var isCacheable: Bool { get }
    
}

public struct ModelGeneratedQueryExpression: QueryExpression {

    public let isCacheable: Bool = true;
    
    let query: String;
    let params: [SQLValue];
    
    public func sqlQuery() -> String {
        print("generated query:", query, params)
        return query;
    }
    
    public func sqlParams() throws -> [SQLValue] {
        return params;
    }
}

public struct ModelQueryExpression<T: SQLCodable>: QueryExpression {
    
    let expression: QueryExpression;
    
    public var isCacheable: Bool {
        return expression.isCacheable;
    }
    
    public static func generated(query: String, params: [SQLValue]) -> ModelQueryExpression<T>  {
        return .init(expression: ModelGeneratedQueryExpression(query: query, params: params));
    }
    
    public static func columnExpression<V: Encodable>(_ keyPath: KeyPath<T,V>, sqlOperator: String, value: V) -> ModelQueryExpression<T> {
        return .init(expression: ColumnBinaryExpression(column: keyPath, sqlOperator: sqlOperator, value: value));
    }

    public static func columnExpression<V: Encodable>(_ keyPath: KeyPath<T,V?>, sqlOperator: String, value: V) -> ModelQueryExpression<T> {
        return .init(expression: ColumnBinaryExpression(column: keyPath, sqlOperator: sqlOperator, value: value));
    }

    public static func equals<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "=", value: value);
    }

    public static func equals<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "=", value: value);
    }

    public static func notEquals<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<>", value: value);
    }

    public static func notEquals<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<>", value: value);
    }

    public static func lessThan<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<", value: value);
    }

    public static func lessThan<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<", value: value);
    }

    public static func greaterThan<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: ">", value: value);
    }

    public static func greaterThan<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: ">", value: value);
    }

    public static func lessThanOrEqual<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<=", value: value);
    }

    public static func lessThanOrEqual<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: "<=", value: value);
    }

    public static func greaterThanOrEqual<V: Encodable>(_ keyPath: KeyPath<T,V>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: ">=", value: value);
    }

    public static func greaterThanOrEqual<V: Encodable>(_ keyPath: KeyPath<T,V?>, value: V) -> ModelQueryExpression<T> {
        return columnExpression(keyPath, sqlOperator: ">=", value: value);
    }

    public static func not(_ expression: ModelQueryExpression<T>) -> ModelQueryExpression<T> {
        return .init(expression: NegationExpression(expression: expression))
    }
    
    public static func and(_ expressions: ModelQueryExpression<T>...) -> ModelQueryExpression<T> {
        return .init(expression: CombiningExpression(sqlOperator: "and", expressions: expressions));
    }

    public static func or(_ expressions: ModelQueryExpression<T>...) -> ModelQueryExpression<T> {
        return .init(expression: CombiningExpression(sqlOperator: "or", expressions: expressions));
    }
    
    public static func `in`<V:SQLCodable&Identifiable>(_ keyPath: KeyPath<T,V>, values: [V]) -> ModelQueryExpression<T> where V.ID == Int {
        return .init(expression: InExpression(column: keyPath, values: values.map({ $0.id })))
    }
    
    public static func literal(_ sql: String) -> ModelQueryExpression<T> {
        return .init(expression: LiteralExpression(query: sql));
    }

    public func sqlQuery() -> String {
        expression.sqlQuery();
    }
    
    public func sqlParams() throws -> [SQLValue] {
        return try expression.sqlParams();
    }
    
}

struct LiteralExpression: QueryExpression {
    let isCacheable: Bool = false
    
    let query: String;
    
    func sqlParams() throws -> [SQLValue] {
        return [];
    }
    
    func sqlQuery() -> String {
        return query;
    }
    
    
}

struct InExpression<T: SQLCodable, V: SQLCodable>: QueryExpression {
 
    let isCacheable: Bool = false;
    
    let column: KeyPath<T,V>;
    let values: [Int];
    
    func sqlQuery() -> String {
        return "in (\(values.map({ $0.description }).joined(separator: ", "))";
    }
    
    func sqlParams() throws -> [SQLValue] {
        return [];
    }
}

struct NegationExpression<T: SQLCodable>: QueryExpression {
    
    let isCacheable: Bool = true;
    
    let expression: ModelQueryExpression<T>;
    
    func sqlParams() throws -> [SQLValue] {
        return try expression.sqlParams();
    }
    
    func sqlQuery() -> String {
        return "not (\(expression.sqlQuery()))"
    }
}

struct CombiningExpression<T: SQLCodable>: QueryExpression {

    var isCacheable: Bool {
        expressions.allSatisfy({ $0.isCacheable })
    }

    let sqlOperator: String;
    let expressions: [ModelQueryExpression<T>];
    
    func sqlParams() throws -> [SQLValue] {
        return try expressions.flatMap({ try $0.sqlParams() })
    }
    
    func sqlQuery() -> String {
        return "(\(expressions.map({ $0.sqlQuery() }).joined(separator: " \(sqlOperator) ")))"
    }
    
    
}

struct ColumnBinaryExpression<T: SQLCodable, V: Encodable>: QueryExpression {
    
    let isCacheable: Bool = true;

    func sqlQuery() -> String {
        return "\(T.keyPathToColumnName(for: column)) \(sqlOperator) ?";
    }
    
    func sqlParams() throws -> [SQLValue] {
        return [try .fromAny(value)];
    }
    
    
    let column: PartialKeyPath<T>;
    let sqlOperator: String;
    let value: V;
    
}
