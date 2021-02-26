//
// DatabasePool.swift
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

public class DatabasePool {
    
    public let configuration: Configuration;
    private var writer: DatabaseWriter;
    private var writerSemphore = DispatchSemaphore(value: 1);
    private let readers: Pool<DatabaseReader>;
    
    public var currentPoolSize: Int {
        return readers.count;
    }
    
    public init(configuration: Configuration) throws {
        self.configuration = configuration;
        let writer = try DatabasePool.openDatabaseWriter(configuration: configuration);
        if let migrator = configuration.schemaMigrator {
            try DatabaseSchemaManager().upgrade(database: writer, migrator: migrator);
        }
        self.writer = writer;
        guard try "wal" == writer.select("PRAGMA journal_mode = WAL").mapFirst({ $0.string(at: 0) }) else {
            throw DBError.internalError;
        }
        try writer.execute("PRAGMA synchronous = NORMAL");
        
        // workaround for missing WAL files
        try writer.withTransaction({ writer in
            try writer.executeQueries("create table workaround(col1 int);drop table workaround;");
        })
                
        readers = try Pool(initialSize: configuration.initialPoolSize, maxSize: configuration.maximalPoolSize, supplier: { try DatabasePool.openDatabaseReader(configuration: configuration)
        });
    }
    
    public func reader(_ block: (DatabaseReader) throws -> Void) throws {
        try readers.execute(block);
    }

    public func reader<T>(_ block: (DatabaseReader) throws -> T) throws -> T {
        return try readers.execute(block);
    }
    
    public func writer(_ block: (DatabaseWriter) throws -> Void) throws {
        writerSemphore.wait();
        defer {
            writerSemphore.signal();
        }
        try block(writer);
    }

    public func writer<T>(_ block: (DatabaseWriter) throws -> T) throws -> T {
        writerSemphore.wait();
        defer {
            writerSemphore.signal();
        }
        return try block(writer);
    }

    static func openDatabaseReader(configuration: Configuration) throws -> DatabaseReader {
        let flags = SQLITE_OPEN_READONLY |  SQLITE_OPEN_NOMUTEX;
        return try openDatabase(configuration: configuration, flags: flags);
    }
    
    static func openDatabaseWriter(configuration: Configuration) throws -> DatabaseWriter {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE |  SQLITE_OPEN_NOMUTEX;
        let database = try openDatabase(configuration: configuration, flags: flags);
        
        // make sure that WAL files are not removed
        var flag: CInt = 1;
        let code = withUnsafeMutablePointer(to: &flag) { flagp in
            sqlite3_file_control(database.connection, nil, SQLITE_FCNTL_PERSIST_WAL, flagp);
        }
        guard let error = DBError(resultCode: code) else {
            return database;
        }
        
        throw error;
    }
    
    static func openDatabase(configuration: Configuration, flags: Int32) throws -> Database {
        return try Database(path: configuration.path, flags: flags);
    }
}

public typealias PoolSupplier<T> = () throws -> T;

public class Pool<T> {
    
    private let queue = DispatchQueue(label: "PoolQueue");
    
    private var items: [Item<T>] = [];
    private let semaphore: DispatchSemaphore;
    private let supplier: PoolSupplier<T>;
    
    public var count: Int {
        return queue.sync(execute: {
            return self.items.count;
        })
    }
    
    public init(initialSize: Int = 1, maxSize: Int, supplier: @escaping PoolSupplier<T>) throws {
        assert(maxSize > 0)
        assert(initialSize <= maxSize);
        self.semaphore = DispatchSemaphore(value: maxSize);
        self.supplier = supplier;
        for _ in 0..<initialSize {
            let value = try supplier();
            items.append(Item(value: value));
        }
    }
            
    public func execute<R>(_ block: (T) throws -> R) throws -> R {
        semaphore.wait();
        let item = try queue.sync { try self.acquire() };
        defer {
            queue.sync {
                item.release();
            }
            semaphore.signal();
        }
        return try block(item.value);
    }
    
    private func acquire() throws -> Item<T> {
        if let it = self.items.first(where: { !$0.inUse }) {
            return it.acquire();
        } else {
            let it = Item(value: try supplier());
            items.append(it);
            return it.acquire();
        }
    }
    
    public class Item<T> {
        
        public let value: T;
        public private(set) var inUse: Bool = false;
        
        init(value: T) {
            self.value = value;
        }
        
        func acquire() -> Item<T> {
            self.inUse = true;
            return self;
        }
        
        func release() {
            self.inUse = false;
        }
        
    }
}
