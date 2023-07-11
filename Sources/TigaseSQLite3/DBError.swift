//
// DBError.swift
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

public enum DBError: Error {
    
    public static func message(from connection: SQLConnection) -> String? {
        if let tmp = sqlite3_errmsg(connection) {
            return String(cString: tmp);
        }
        return nil;
    }
    
    private static let successCodes = [ SQLITE_OK, SQLITE_ROW, SQLITE_DONE ];
        
    case sqliteError(errorCode: Int32, message: String?)
    case invalidParameterName(name: String)
    case unsupportedType(name: String)
    case internalError
    case invalidResult
        
    init?(resultCode: Int32) {
        guard !DBError.successCodes.contains(resultCode) else {
            return nil;
        }

        self = .sqliteError(errorCode: resultCode, message: nil);
    }

    public init?(connection: SQLConnection, resultCode: Int32) {
        guard !DBError.successCodes.contains(resultCode) else {
            return nil;
        }

        self = .sqliteError(errorCode: resultCode, message: DBError.message(from: connection));
    }
    
//    public init?(database: Database, resultCode: Int32) {
//        guard !DBError.successCodes.contains(resultCode) else {
//            return nil;
//        }
//
//        self = .sqliteError(errorCode: resultCode, message: database.errorMessage);
//    }
}
