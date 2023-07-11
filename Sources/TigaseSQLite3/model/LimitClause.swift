//
// LimitClause.swift
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

public struct LimitClause: SQLParameterProvider {
    
    public static func limit(_ limit: Int, offset: Int? = nil) -> LimitClause {
        return .init(limit: limit, offset: offset);
    }
    
    public static func offset(_ offset: Int) -> LimitClause {
        return .init(limit: nil, offset: offset);
    }
    
    let limit: Int?;
    let offset: Int?;
    
    public func sqlQuery() -> String {
        guard limit != nil else {
            guard offset != nil else {
                fatalError("LimitClause with invalid paramters!");
            }
            return "OFFSET ?";
        }
        guard offset != nil else {
            return "LIMIT ?"
        }
        return "LIMIT ? OFFSET ?";
    }
    
    public func sqlParams() -> [SQLValue] {
        guard let limit else {
            guard let offset else {
                fatalError("LimitClause with invalid paramters!");
            }
            return [.integer(offset)];
        }
        guard let offset else {
            return [.integer(limit)]
        }
        return [.integer(limit), .integer(offset)];
    }
    
}
