//
// OrderClause.swift
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

public struct OrderClause<T: SQLCodable>: SQLQueryProvider {
    
    public static func ascending(_ column: PartialKeyPath<T>) -> OrderClause<T> {
        return .init(column: column, direction: .ascending);
    }

    public static func descending(_ column: PartialKeyPath<T>) -> OrderClause<T> {
        return .init(column: column, direction: .descending);
    }

    enum Direction {
        case ascending
        case descending
    }
    
    let column: PartialKeyPath<T>;
    let direction: Direction;
    
    init(column: PartialKeyPath<T>, direction: Direction) {
        self.column = column;
        self.direction = direction;
    }
    
    public func sqlQuery() -> String {
        let column = T.keyPathToColumnName(for: self.column);
        return "\(column)\(direction == .descending ? " DESC" : "")"
    }
    
    
}
