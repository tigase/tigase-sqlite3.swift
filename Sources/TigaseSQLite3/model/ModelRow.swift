//
// ModelRow.swift
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

public struct ModelRow<T: SQLCodable>: CustomDebugStringConvertible, Equatable {

    public var debugDescription: String {
        return "ModelRow(row: \(row.debugDescription))"
    }
    
    let row: Row;
    
    
    init(row: Row) {
        self.row = row;
    }
    
    public subscript(_ columnName: String) -> SQLValue? {
        return row[columnName];
    }
    
    public subscript<V: Decodable>(_ keyPath: KeyPath<T,V>) -> V {
        return row[keyPath];
    }
    
    public subscript<V: Decodable>(_ keyPath: KeyPath<T,V?>) -> V? {
        return row[keyPath];
    }

}
