//
// DatabaseConvertibleTest.swift
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
import TigaseSQLite3

import XCTest

class DatabaseConvertibleTest: XCTestCase {

    var database: Database?;
    
    override func setUpWithError() throws {
        try database = Database(path: ":memory:");
        try database?.execute(query: "create table t1(col1 id integer primary key asc, col2 text)");
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try database?.execute(query: "drop table t1");
        database = nil;
    }

    func testExample() throws {
        let jid = JID("test-value");
        try database?.insert("insert into t1(col2) values (:jid)", params: ["jid": jid])
        let result = try database?.select("select col2 from t1").mapFirst { $0.jid(at: 0) };
        XCTAssertEqual(jid, result, "database convertible values do not match");
    }

    func testCodable() throws {
        let value = JSONContainer(user: "Test", password: "Password");
        try database?.insert("insert into t1(col2) values (:value)", params: ["value": value]);
        let result = try database?.select("select col2 from t1").mapFirst { c -> JSONContainer? in c.object(at: 0) };
        XCTAssertEqual(value, result, "database convertible values do not match");
    }
}

class JSONContainer: Codable, DatabaseConvertibleStringValue, Equatable {
    static func == (lhs: JSONContainer, rhs: JSONContainer) -> Bool {
        return lhs.user == rhs.user && lhs.password == rhs.password;
    }
    
    func encode() -> String {
        return String(data: try! JSONEncoder().encode(self), encoding: .utf8)!;
    }
    
    enum CodingKeys: String, CodingKey {
        case user
        case password
    }
    
    let user: String;
    let password: String;
    
    public init(user: String, password: String) {
        self.user = user;
        self.password = password;
    }
}

class JID: Equatable {
    static func == (lhs: JID, rhs: JID) -> Bool {
        return lhs.value == rhs.value;
    }
    
    
    let value: String;
    
    init(_ value: String) {
        self.value = value;
    }
        
}

extension JID: DatabaseConvertibleStringValue {

    func encode() -> String {
        return value;
    }
    
}

extension Cursor {
    
    func jid(at column: Int) -> JID? {
        guard let value: String = self[column] else {
            return nil;
        }
        return JID(value);
    }
}
