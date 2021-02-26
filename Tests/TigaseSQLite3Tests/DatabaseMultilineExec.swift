//
// DatabaseMultilineExec.swift
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

class DatabaseMultilineExec: XCTestCase {

    var database: Database?;
    
    override func setUpWithError() throws {
        try database = Database(path: "file::memory:");
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        database = nil;
    }

    func test() throws {
        try database?.executeQueries("create table test1(col1 integer, col2 text);\ncreate table test2(col1 integer, col2 text)");
        try database?.select("select col1, col2 from test1");
        try database?.select("select col1, col2 from test2");
    }
    
    func testTrasnaction1() throws {
        try database?.withTransaction({ database in
            try database.executeQueries("create table test1(col1 integer, col2 text);\ncreate table test2(col1 integer, col2 text)");
        })
        try database?.select("select col1, col2 from test1");
        try database?.select("select col1, col2 from test2");
    }


    func testTrasnaction2() throws {
        try database?.execute("BEGIN TRANSACTION;");
        try database?.executeQueries("create table test1(col1 integer, col2 text);\ncreate table test2(col1 integer, col2 text)");
        try database?.execute("COMMIT TRANSACTION;");
        try database?.select("select col1, col2 from test1");
        try database?.select("select col1, col2 from test2");
    }

}
