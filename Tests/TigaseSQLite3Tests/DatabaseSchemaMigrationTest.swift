//
// DatabaseSchemaMigrationTest.swift
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
import XCTest
import TigaseSQLite3

class DatabaseSchemaMigrationTest: XCTestCase {

    var database: Database?;
    
    override func setUpWithError() throws {
        try database = Database(path: "file::memory:");
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        database = nil;
    }

    func testSimple() throws {
        let migrator = DatabaseMigrator();
        let manager = DatabaseSchemaManager();
        try manager.upgrade(database: database!, migrator: migrator);
        XCTAssertEqual(migrator.upgradedVersions, [1,2]);
        XCTAssertEqual(try manager.schemaVersion(database: database!), 2);
    }

    func testRollback() throws {
        let migrator = DatabaseMigrator2();
        let manager = DatabaseSchemaManager();
        do {
            try manager.upgrade(database: database!, migrator: migrator);
            XCTAssertTrue(false);
        } catch {
            // it is expected
            XCTAssertTrue(true);
        }
        
        XCTAssertEqual(try manager.schemaVersion(database: database!), 1);
        
        let count = try database!.count("select count(*) from t1", cached: false);
        XCTAssertEqual(count, 1);
        
        do {
            _ = try database?.count("select count(*) from t2", cached: false)
            XCTAssertTrue(false);
        } catch {
            XCTAssertTrue(true);
        }
    }
    
}

class DatabaseMigrator: DatabaseSchemaMigrator {
    
    let expectedVersion: Int = 2
    
    var upgradedVersions: [Int] = [];
    
    func upgrade(database: DatabaseWriter, newVersion: Int) throws {
        upgradedVersions.append(newVersion);
    }
    
    
}


class DatabaseMigrator2: DatabaseSchemaMigrator {
    
    let expectedVersion: Int = 2
        
    func upgrade(database: DatabaseWriter, newVersion: Int) throws {
        switch newVersion {
        case 1:
            try database.execute("create table t1 (col1 integer, col2 text)");
            try database.insert("insert into t1 (col2) values (:text)", params: ["text": "Hello world"]);
        case 2:
            try database.execute("create table t2 (col1 integer, col2 text)");
            try database.insert("insert into t1 (col2) values (:text)", params: ["text": "Hello world 2"]);
            throw DBError.internalError;
        default:
            break;
        }
    }
    
}
