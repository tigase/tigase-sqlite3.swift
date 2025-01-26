//
// DatabaseWriter.swift
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

public protocol DatabaseWriter: DatabaseReader {
    
    var changesCount: Int { get }
    var lastInsertedId: Int { get }
        
    func changePublisher(for tableName: String) -> AnyPublisher<Change,Never>;
    
    func withTransaction<R>(_ block: (DatabaseWriter) throws -> R) throws -> R;
    
    func delete(_ query: String, cached: Bool, params: [SQLValue]) throws;
    
    func delete(_ query: String, cached: Bool, params: [String:SQLValue]) throws;

    func insert(_ query: String, cached: Bool, params: [SQLValue]) throws;
    
    func insert(_ query: String, cached: Bool, params: [String:SQLValue]) throws;
    
    func update(_ query: String, cached: Bool, params: [SQLValue]) throws;
    
    func update(_ query: String, cached: Bool, params: [String:SQLValue]) throws;
 
    func execute(_ query: String) throws;
}

extension DatabaseWriter {
    
    public func delete(_ query: String, cached: Bool = true, params: [String: Encodable?]) throws {
        try delete(query, cached: cached, params: params.mapValues(SQLValue.fromAny(_:)));
    }

    public func delete(_ query: String, cached: Bool = true, params: [Encodable?] = []) throws {
        try delete(query, cached: cached, params: params.map(SQLValue.fromAny(_:)));
    }

    public func insert(_ query: String, cached: Bool = true, params: [String: Encodable?]) throws {
        try insert(query, cached: cached, params: params.mapValues(SQLValue.fromAny(_:)));
    }

    public func insert(_ query: String, cached: Bool = true, params: [Encodable?] = []) throws {
        try insert(query, cached: cached, params: params.map(SQLValue.fromAny(_:)));
    }
    
    public func update(_ query: String, cached: Bool = true, params: [String: Encodable?]) throws {
        try update(query, cached: cached, params: params.mapValues(SQLValue.fromAny(_:)));
    }

    public func update(_ query: String, cached: Bool = true, params: [Encodable?] = []) throws {
        try update(query, cached: cached, params: params.map(SQLValue.fromAny(_:)));
    }

}

extension DatabaseWriter {
    
    public func delete(_ query: String,  params: [SQLValue]) throws {
        try delete(query, cached: true, params: params)
    }
    
    public func insert(_ query: String, params: [SQLValue]) throws {
        try insert(query, cached: true, params: params)
    }

    public func update(_ query: String, params: [SQLValue]) throws {
        try update(query, cached: true, params: params)
    }
}

import Combine

public struct Change: Sendable {
    
    public let table: String;
    public let rowIds: Set<Int64>;
    
}

class ChangesObserver {
    
    private final class State {
        var publishers: [String: PassthroughSubject<Change,Never>] = [:];
        var changes: [String: Change] = [:];
        var transactions: Set<UInt64> = [];
    }
    
    private let state = UnfairLock(state: State());

    func beginTransaction(_ transactionId: UInt64) {
        state.with({
            $0.transactions.insert(transactionId);
        })
    }
    
    func endTransaction(_ transactionId: UInt64) {
        let needFlush = state.with({
            $0.transactions.remove(transactionId);
            return $0.transactions.isEmpty && !$0.changes.isEmpty;
        })
        if needFlush {
            flush();
        }
    }
    
    func changePublisher(table: String) -> AnyPublisher<Change, Never> {
        return state.with({
            guard let publisher = $0.publishers[table] else {
                let publisher = PassthroughSubject<Change,Never>();
                $0.publishers[table] = publisher;
                return publisher;
            }
            return publisher;
        }).eraseToAnyPublisher();
    }
    
    func reportChange(table: String, rowId: Int64) {
        let needFlush = state.with({
            if let change = $0.changes[table] {
                var rowsIds = change.rowIds;
                rowsIds.insert(rowId);
                $0.changes[table] = Change(table: table, rowIds: rowsIds);
            } else {
                $0.changes[table] = Change(table: table, rowIds: [rowId]);
            }
            return $0.transactions.isEmpty;
        });
        if needFlush {
            flush();
        }
    }
 
    private func flush() {
        state.with({
            for (table,change) in $0.changes {
                if let publisher = $0.publishers[table] {
                    publisher.send(change);
                }
            }
            $0.changes.removeAll(keepingCapacity: false);
        })
    }
}

