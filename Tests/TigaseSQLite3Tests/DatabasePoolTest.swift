//
// DatabasePoolTest.swift
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

class DatabasePoolTest: XCTestCase {

    var databasePool: DatabasePool?;
    
    override func setUpWithError() throws {
        try databasePool = DatabasePool(configuration: Configuration(path: "file::memory"));
        try databasePool?.execute("create table t1(col1 id integer primary key asc, col2 text)");
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try databasePool?.execute("drop table t1");
        databasePool = nil;
    }

    func testSimple() throws {
        let jid = JID("test-value");
        try databasePool?.insert("insert into t1(col2) values (:jid)", params: ["jid": jid])
        
        let result: JID? = try databasePool?.select("select col2 from t1").first?["col2"]// { $0.jid(at: 0) };
        XCTAssertEqual(jid, result, "database convertible values do not match");
    }

    func testAdvanced() throws {
        let jid = JID("test-value");
        try databasePool?.insert("insert into t1(col2) values (:jid)", params: ["jid": jid])

        let result: JID? = try databasePool?.reader({ db1 -> JID? in
            let x2 = try databasePool?.reader({ db2 -> JID? in
                let x3 = try databasePool?.reader({ db3 -> JID? in
                    XCTAssert(db3 !== db2)
                    return try db3.select("select col2 from t1").first?["col2"];// { $0.jid(at: 0) };
                });
                XCTAssert(db1 !== db2)
                let x2: JID? = try db2.select("select col2 from t1").first?["col2"];//.mapFirst { $0.jid(at: 0) };
                XCTAssertEqual(x3, x2);
                return x2;
            })
            let x1: JID? = try db1.select("select col2 from t1").first?["col2"];//.mapFirst { $0.jid(at: 0) };
            XCTAssertEqual(x1, x2);
            return x1;
        });
        XCTAssertEqual(jid, result, "database convertible values do not match");
    }
    
    func testChangePublisher() throws {
        let jid = JID("test-value");
        let jid2 = JID("test2-value");
        let publisher = databasePool!.changePublisher(for: "t1");
//        let publisher = try databasePool!.writer({ database in
//            database.changePublisher(for: "t1");
//        });
        let cancellable = publisher.sink(receiveValue: { change in
            print("changed row: \(change)");
        });
        try databasePool!.insert("insert into t1(col2) values (:jid)", params: ["jid": jid]);
        try databasePool!.withTransaction({ database in
            try database.update("update t1 set col2 = :jid where col2 = :jid1", params: ["jid1": jid, "jid": jid2]);
            try database.update("update t1 set col2 = :jid where col2 = :jid1", params: ["jid1": jid, "jid": jid2]);
            try database.insert("insert into t1(col2) values (:jid)", params: ["jid": jid]);
        })
    }

    // Measured time is 0.212s
    func testPerformanceSingle() throws {
        try databasePool?.writer({ database in
            for i in 0..<1000 {
                try database.insert("insert into t1(col2) values (:name)", cached: true, params: ["name": "test-\(i)"]);
            }
        })
        self.measure {
            do {
                for _ in 0..<1000 {
                    let count = try databasePool!.select("select * from t1", cached: true).count;
                    assert(count == 1000)
                }
            } catch {}
        }
    }
    
    // Measured time is 0.0296s
    // concurrent querying is about 7 times faster using 5 connections
    func testPerformanceMulti() throws {
        try databasePool?.writer({ database in
            for i in 0..<1000 {
                try database.insert("insert into t1(col2) values (:name)", cached: true, params: ["name": "test-\(i)"]);
            }
        })
        let queues: [OperationQueue] = (0..<5).map({ _ in OperationQueue() });
        queues.forEach({ $0.isSuspended = true })
        for i in 0..<5 {
            for _ in 0..<200 {
                queues[i].addOperation {
                    do {
                        let count = try self.databasePool!.select("select * from t1", cached: true).count;
                        assert(count == 1000)
                    } catch {}
                }
            }
        }
        self.measure {
            for i in 0..<queues.count {
                queues[i].isSuspended = false;
            }
            for i in 0..<queues.count {
                queues[i].waitUntilAllOperationsAreFinished();
            }
        }
    }
}
