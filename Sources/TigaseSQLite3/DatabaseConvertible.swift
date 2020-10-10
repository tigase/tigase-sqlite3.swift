//
// DatabaseConvertible.swift
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

public protocol DatabaseConvertibleStringValue {
    
    func encode() -> String
    
}

public protocol DatabaseConvertibleDataValue {
    
    func encode() -> Data;
    
}

public protocol DatabaseConvertibleIntValue {
    
    func encode() -> Data;
    
}

extension Encodable where Self: DatabaseConvertibleStringValue {

    public func encode() -> String {
        let data = try! JSONEncoder().encode(self);
        return String(data: data, encoding: .utf8)!;
    }

}
