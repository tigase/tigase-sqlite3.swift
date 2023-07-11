//
// SQLCodableMapper.swift
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

public class SQLCodableMapper {

    public struct Mappings {
        let keyPathToColumn: [AnyKeyPath:String];
    }

    private static let lock = UnfairLock();
    private static var mappings: [ObjectIdentifier: Mappings] = [:]

    public static func mappings<T: SQLCodable>(for type: T.Type) -> Mappings {
        lock.with {
            let id = ObjectIdentifier(type);
            guard let mappings = self.mappings[id] else {
                let keyPathToColumn = Dictionary.init(uniqueKeysWithValues: type.fields.map({ ($0.keyPath,$0.column) }))
                let mappings = Mappings(keyPathToColumn: keyPathToColumn);
                self.mappings[id] = mappings;
                return mappings;
            }
            return mappings;
        }
    }

    public static func mapping<T: SQLCodable>(for keyPath: PartialKeyPath<T>) -> String {
        guard let name = mappings(for: T.self).keyPathToColumn[keyPath] else {
            fatalError("Missing mapping for \(keyPath)");
        }
        return name;
    }

}
