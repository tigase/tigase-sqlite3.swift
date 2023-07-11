//
// LiveQueryWithRelation.swift
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
import Combine

public class LiveQueryWithRelation<T: SQLCodable>: ObservableObject {
    
    public let database: DatabasePool
    @Published
    public var results: [T] = [];
    public var query: ModelQueryExpression<T>?;
    public var orderBy: [OrderClause<T>]?;
    private var cancellable: AnyCancellable?;
    
    public init(database: DatabasePool, from type: T.Type, where query: ModelQueryExpression<T>? = nil, orderBy: [OrderClause<T>]? = nil) {
        self.database = database;
        self.query = query;
        self.orderBy = orderBy;
        var publisher = database.changePublisher(for: type.tableName);
        for relationTable in type.relationTables {
            publisher = publisher.combineLatest(database.changePublisher(for: relationTable), { c1,c2 in
                return c1;
            }).eraseToAnyPublisher();
        }
        // receive(on: DispatchQueue.global(qos: .userInteractive))
        cancellable = publisher.sink(receiveValue: { [weak self] change in
            self?.update();
        });
        self.update();
    }
    
    private func update() {
        results = try! T.findAll(in: self.database, where: query, withRelations: true);
    }
    
}
