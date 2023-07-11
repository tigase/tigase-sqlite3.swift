//
// DatabaseReader+Model.swift
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

extension DatabaseReader {

    public func max<T: SQLCodable>(_ type: T.Type, column: PartialKeyPath<T>, where query: ModelQueryExpression<T>? = nil, indexedBy: String? = nil) throws -> Int {
        let columns = "max(\(T.keyPathToColumnName(for: column))";
        return try selectFirst(from: type, columns: columns, where: query, indexedBy: indexedBy)?["max"]?.int ?? 0;
    }

    public func min<T: SQLCodable>(_ type: T.Type, column: PartialKeyPath<T>, where query: ModelQueryExpression<T>? = nil, indexedBy: String? = nil) throws -> Int {
        let columns = "min(\(T.keyPathToColumnName(for: column))";
        return try selectFirst(from: type, columns: columns, where: query, indexedBy: indexedBy)?["min"]?.int ?? 0;
    }

    public func count<T: SQLCodable>(_ type: T.Type, column: PartialKeyPath<T>? = nil, where query: ModelQueryExpression<T>? = nil, indexedBy: String? = nil) throws -> Int {
        let columns = "count(\(column != nil ? T.keyPathToColumnName(for: column!) : "*"))";
        return try selectFirst(from: type, columns: columns, where: query, indexedBy: indexedBy)?["count"]?.int ?? 0;
    }
    
    public func selectFirst<T: SQLCodable>(from type: T.Type, columns: [PartialKeyPath<T>]? = nil, where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, indexedBy: String? = nil) throws -> ModelRow<T>? {
        return try select(from: type, columns: columns, where: query, orderBy: orderBy, limit: .limit(1), indexedBy: indexedBy).first;
    }
    
    public func selectFirst<T: SQLCodable>(from type: T.Type, columns: String, where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, indexedBy: String? = nil) throws -> Row? {
        return try select(from: type, columns: columns, where: query, orderBy: orderBy, limit: .limit(1), indexedBy: indexedBy).first;
    }
 
    public func select<T: SQLCodable>(from type: T.Type, columns: String, where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil) throws -> [Row] {
        let sql = prepareSelectSQL(type: T.self, columns: columns, where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
        let params = try prepareSelectParams(query: query, limit: limit);
        return try select(sql, params: params);
    }

    public func select<T: SQLCodable>(from type: T.Type, columns: [PartialKeyPath<T>]? = nil, where query: ModelQueryExpression<T>? = nil, groupBy: [PartialKeyPath<T>]? = nil, orderBy: [OrderClause<T>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil) throws -> [ModelRow<T>] {
        let sql = prepareSelectSQL(type: T.self, columns: columns, where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
        let params = try prepareSelectParams(query: query, limit: limit);
        return try select(sql, params: params).map({ .init(row: $0) });
    }

    public func select<T: SQLCodable>(columns: [PartialKeyPath<T>]? = nil, where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil) throws -> [ModelRow<T>] {
        return try select(from: T.self, columns: columns, where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
    }
    
    public func select<T: SQLCodable>(where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil) throws -> [T] {
        return try select(where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy).map({ T.init(model: $0) });
    }
    
    public func selectWithRelations<T: SQLCodable>(where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil, limit: LimitClause? = nil, indexedBy: String? = nil) throws -> [T] {
        let items: [T] = try select(where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
        try T.loadRelations(from: self, for: items);
        return items;
    }

    private func prepareSelectSQLColumns<T: SQLCodable>(_ columns: [PartialKeyPath<T>]?) -> [String] {
        return columns?.map({ T.keyPathToColumnName(for: $0)}) ?? ["*"];
    }
    
    public func prepareSelectSQL<T: SQLCodable>(type: T.Type, columns: [PartialKeyPath<T>]? = nil, where query: ModelQueryExpression<T>?, orderBy: [OrderClause<T>]?, limit: LimitClause?, indexedBy: String?) -> String {
        let columnsStr = prepareSelectSQLColumns(columns).joined(separator: ", ");
        return prepareSelectSQL(type: type, columns: columnsStr, where: query, orderBy: orderBy, limit: limit, indexedBy: indexedBy);
    }

    public func prepareSelectSQL<T: SQLCodable>(type: T.Type, columns: String, where query: ModelQueryExpression<T>?, orderBy: [OrderClause<T>]?, limit: LimitClause?, indexedBy: String?) -> String {
        var sql = "SELECT \(columns) FROM \(type.tableName)";
        if let indexedBy {
            sql = " INDEXED BY \(indexedBy)"
        }
        if let query {
            sql += " WHERE \(query.sqlQuery())"
        }
        if let orderBy {
            sql += " ORDER BY \(orderBy.map({ $0.sqlQuery() }).joined(separator: ", "))"
        }
        if let limit {
            sql += " \(limit.sqlQuery())";
        }
        return sql;
    }
    
    public func prepareSelectParams<T>(query: ModelQueryExpression<T>?, limit: LimitClause?) throws -> [SQLValue] {
        return (try query?.sqlParams() ?? []) + (limit?.sqlParams() ?? []);
    }

//        let params = try query?.paramsForQuery() ?? [];
//        return ModelQuery(sql: sql, params: params);
//    }
//    func selectTest<T: SQLCodable>() -> T {
//
//    }
    
}
