//
// Cursor+Getters.swift
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
    public func double(at column: Int) -> Double? {
        return self[column];
    }
    
    public func int(at column: Int) -> Int? {
        return self[column];
    }
    
    public func string(at column: Int) -> String? {
        return self[column];
    }
    
    public func bool(at column: Int) -> Bool {
        return self[column];
    }
    
    public func data(at column: Int) -> Data? {
        return self[column];
    }
    
    public func date(at column: Int) -> Date? {
        return self[column];
    }
            
}

extension Cursor {
            
    public func int(for column: String) -> Int? {
        return self[column];
    }

    public func double(for column: String) -> Double? {
        return self[column];
    }

    public func string(for column: String) -> String? {
        return self[column];
    }
    
    public func bool(for column: String) -> Bool {
        return self[column];
    }

    public func data(for column: String) -> Data? {
        return self[column];
    }

    public func date(for column: String) -> Date? {
        return self[column];
    }
    
}
