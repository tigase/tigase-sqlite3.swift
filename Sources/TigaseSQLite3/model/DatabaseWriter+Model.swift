//
// DatabaseWriter+Model.swift
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

extension DatabaseWriter {
    
    public func insert<T: SQLCodable>(_ type: T.Type, values: [ModelInsertExpression<T>]) throws {
        let sql = prepareInsertSQL(type: type, values: values);
        let params = try prepareInsertParams(type: type, values: values);
        try self.insert(sql, params: params);
    }
    
    public func prepareInsertSQL<T: SQLCodable>(type: T.Type, values: [ModelInsertExpression<T>]) -> String {
        let columnsStr = values.map({ $0.sqlQuery() }).joined(separator: ", ")
        return "INSERT INTO \(type.tableName) (\(columnsStr)) VALUES (\(values.map({ _ in "?"}).joined(separator: ", ")))";
    }
    
    public func prepareInsertParams<T: SQLCodable>(type: T.Type, values: [ModelInsertExpression<T>]) throws -> [SQLValue] {
        return try values.flatMap({ try $0.sqlParams() });
    }
    
    public func update<T: SQLCodable>(_ type: T.Type, set update: [ModelUpdateExpression<T>], where query: ModelQueryExpression<T>? = nil, indexedBy: String? = nil) throws {
        let sql = prepareUpdateSQL(type: type, set: update, where: query, indexedBy: indexedBy);
        let params = try prepareUpdateParams(type: type, set: update, where: query);
        try self.update(sql, params: params);
    }

    public func update<T: SQLCodable>(_ type: T.Type, set update: String, where query: ModelQueryExpression<T>? = nil, indexedBy: String? = nil) throws {
        let sql = prepareUpdateSQL(type: type, set: update, where: query, indexedBy: indexedBy);
        let params = try query?.sqlParams() ?? [];
        try self.update(sql, params: params);
    }

    public func prepareUpdateSQL<T: SQLCodable>(type: T.Type, set update: [ModelUpdateExpression<T>], where query: ModelQueryExpression<T>?, indexedBy: String?) -> String {
        let columnsStr = update.map({ $0.sqlQuery() }).joined(separator: ", ")
        return prepareUpdateSQL(type: type, set: columnsStr, where: query, indexedBy: indexedBy);
    }

    public func prepareUpdateSQL<T: SQLCodable>(type: T.Type, set update: String, where query: ModelQueryExpression<T>?, indexedBy: String?) -> String {
        let indexedByStr = indexedBy == nil ? "" : " INDEXED BY \(indexedBy!)";
        var sql = "UPDATE \(T.tableName)\(indexedByStr) SET \(update)";
        if let query {
            sql += " WHERE \(query.sqlQuery())"
        }
        return sql;
    }
    
    public func prepareUpdateParams<T: SQLCodable>(type: T.Type, set update: [ModelUpdateExpression<T>], where query: ModelQueryExpression<T>?) throws -> [SQLValue] {
        return try update.flatMap({ try $0.sqlParams() }) + (try query?.sqlParams() ?? []);
    }

    public func delete<T: SQLCodable>(_ type: T.Type, where query: ModelQueryExpression<T>? = nil) throws {
        let sql = prepareDeleteSQL(type: type, where: query);
        let params = try prepareDeleteParams(type: type, query: query);
        try self.delete(sql, params: params)
    }
    
    public func prepareDeleteSQL<T: SQLCodable>(type: T.Type, where query: ModelQueryExpression<T>? = nil) -> String {
        var sql = "DELETE FROM \(type.tableName)";
        if let query {
            sql += " WHERE \(query.sqlQuery())"
        }
        return sql;
    }
    
    public func prepareDeleteParams<T: SQLCodable>(type: T.Type, query: ModelQueryExpression<T>?) throws -> [SQLValue] {
        return try query?.sqlParams() ?? [];
    }
}
