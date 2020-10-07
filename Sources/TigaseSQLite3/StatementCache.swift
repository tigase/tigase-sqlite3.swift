//
// StatementCache.swift
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
import CSQLite

public class StatementCache {
    
    private unowned let database: Database;
    private var statements: [String: Statement] = [:];
    
    init(database: Database) {
        self.database = database;
    }
    
    deinit {
        statements.removeAll();
    }
    
    public func statement(query: String) throws -> Statement {
        guard let statement = statements[query] else {
            let statement = try database.createStatement(query: query);
            statements[query] = statement;
            return statement;
        }
        return statement;
    }
    
    public func invalidate() {
        statements.removeAll();
    }
}

