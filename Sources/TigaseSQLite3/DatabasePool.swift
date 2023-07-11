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
import Combine

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
        guard try "wal" == writer.select("PRAGMA journal_mode = WAL").first?["journal_mode"] else {
            throw DBError.internalError;
        }
        try writer.execute("PRAGMA synchronous = NORMAL");
        
        // workaround for missing WAL files
        try writer.withTransaction({ writer in
            try writer.execute("create table workaround(col1 int);drop table workaround;");
        })
                
        readers = try Pool(initialSize: configuration.initialPoolSize, maxSize: configuration.maximalPoolSize, supplier: { try DatabasePool.openDatabaseReader(configuration: configuration)
        });
    }
    
    public func changePublisher(for table: String) -> AnyPublisher<Change,Never> {
        return writer.changePublisher(for: table);
    }
    
    public func reader(_ block: (DatabaseReader) throws -> Void) rethrows {
        try readers.execute(block);
    }

    public func reader<T>(_ block: (DatabaseReader) throws -> T) rethrows -> T {
        return try readers.execute(block);
    }
    
    public func writer(_ block: (DatabaseWriter) throws -> Void) rethrows {
        writerSemphore.wait();
        defer {
            writerSemphore.signal();
        }
        try block(writer);
    }

    public func writer<T>(_ block: (DatabaseWriter) throws -> T) rethrows -> T {
        writerSemphore.wait();
        defer {
            writerSemphore.signal();
        }
        return try block(writer);
    }

    static func openDatabaseReader(configuration: Configuration) throws -> DatabaseReader {
        let flags = SQLITE_OPEN_READONLY |  SQLITE_OPEN_NOMUTEX;
        return try openDatabase(configuration: configuration, flags: flags, options: []);
    }
    
    static func openDatabaseWriter(configuration: Configuration) throws -> DatabaseWriter {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE |  SQLITE_OPEN_NOMUTEX;
        return try openDatabase(configuration: configuration, flags: flags, options: [.wal]);
    }
    
    static func openDatabase(configuration: Configuration, flags: Int32, options: Database.Options) throws -> Database {
        return try Database(path: configuration.path, flags: flags, options: options);
    }
}

extension DatabasePool: DatabaseReaderInternal, DatabaseWriterInternal {

    func readInternal<R>(_ block: (DatabaseReader) throws -> R) rethrows -> R {
        return try reader(block);
    }
    
    func writeInternal<R>(_ block: (DatabaseWriter) throws -> R) rethrows -> R {
        return try writer(block);
    }
    
    public func execute(_ query: String) throws {
        return try writer({ writer in
            try writer.execute(query);
        })
    }
    
    
}

public typealias PoolSupplier<T> = () throws -> T;

public class Pool<T> {
    
    private let queue = DispatchQueue(label: "PoolQueue");
    
    private var items: [Item] = [];
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
            
    public func execute<R>(_ block: (T) throws -> R) rethrows -> R {
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
    
    private func acquire() throws -> Item {
        if let it = self.items.first(where: { !$0.inUse }) {
            return it.acquire();
        } else {
            let it = Item(value: try supplier());
            items.append(it);
            return it.acquire();
        }
    }
    
    public class Item {
        
        public let value: T;
        public private(set) var inUse: Bool = false;
        
        init(value: T) {
            self.value = value;
        }
        
        func acquire() -> Item {
            self.inUse = true;
            return self;
        }
        
        func release() {
            self.inUse = false;
        }
        
    }
}
