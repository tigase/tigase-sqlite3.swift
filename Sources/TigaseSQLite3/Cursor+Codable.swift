//
// Cursor+Codable.swift
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

extension Cursor {
    
    public func object<T: Codable>(at column: Int) -> T? {
        guard let value = string(at: column) else {
            return nil;
        }
        return try? JSONDecoder().decode(T.self, from: value.data(using: .utf8)!);
    }

    public func object<T: Codable>(for column: String) -> T? {
        guard let value = string(for: column) else {
            return nil;
        }
        return try? JSONDecoder().decode(T.self, from: value.data(using: .utf8)!);
    }

}


