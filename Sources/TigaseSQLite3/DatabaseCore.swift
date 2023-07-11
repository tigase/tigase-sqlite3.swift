//
//  File.swift
//  
//
//  Created by Andrzej Wójcik on 18/06/2023.
//

import Foundation
import os
import Combine
import SQLite3

public typealias SQLConnection = OpaquePointer;

final class DatabaseCore: DatabaseWriter {
    
    private let logger = Logger(subsystem: "tigase.sqlite3", category: "DatabaseCore")
    
    private let connection: SQLConnection;
    private var statementsCache: [String: Statement] = [:];
    private var transactionIdCounter: UInt64 = 1;
    
    private let changesObserver = ChangesObserver();
    
    public var changesCount: Int {
        return Int(sqlite3_changes(connection));
    }
    
    public var lastInsertedId: Int {
        return Int(sqlite3_last_insert_rowid(connection));
    }
    
    private func nextTransactionId() -> UInt64 {
        defer {
            transactionIdCounter = transactionIdCounter + 1;
        }
        return transactionIdCounter;
    }
    
    init (path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, options: Database.Options) throws {
        var handle: OpaquePointer? = nil;
        var code = sqlite3_open_v2(path, &handle, flags, nil);
        guard code == SQLITE_OK, let openedHandle = handle else {
            sqlite3_close_v2(handle);
            throw DBError(resultCode: code) ?? DBError.internalError;
        }
        // make sure that WAL files are not removed
        if options.contains(.wal) {
            logger.info("enabling WAL mode...")
            var flag: CInt = 1;
            code = withUnsafeMutablePointer(to: &flag) { flagp in
                sqlite3_file_control(openedHandle, nil, SQLITE_FCNTL_PERSIST_WAL, flagp);
            }
            if let error = DBError(resultCode: code) {
                throw error;
            }
        }
        self.connection = openedHandle;
        sqlite3_update_hook(handle, { ctx, operation, cDatabaseName, cTableName, rowId in
            guard let ctx, let cTableName, let tableName = String(cString: cTableName, encoding: .utf8) else { return };
            let observer: ChangesObserver = Unmanaged.fromOpaque(ctx).takeUnretainedValue();
            observer.reportChange(table: tableName, rowId: rowId);
        }, Unmanaged<ChangesObserver>.passUnretained(changesObserver).toOpaque());
    }
    
    func execute(_ query: String) throws {
        logger.trace("executing SQL query:\n\(query)")
        let code = sqlite3_exec(self.connection, query, nil, nil, nil);
        guard let error = DBError(connection: self.connection, resultCode: code) else {
            return;
        }
        
        throw error;
    }

    @discardableResult
    private func execute(_ query: String, cached: Bool, params: [SQLValue]) throws -> [Row] {
        logger.trace("executing SQL: \(query) with params: \(params)")
        return try statement(query, cached: cached).execute(params: params);
    }

    @discardableResult
    private func execute(_ query: String, cached: Bool, params: [String: SQLValue]) throws -> [Row] {
        logger.trace("executing SQL: \(query) with params: \(params)")
        return try statement(query, cached: cached).execute(params: params);
    }

    private func transaction<R>(_ block: (_ core: DatabaseCore) throws -> R) throws -> R {
        let transactionId = nextTransactionId();
        changesObserver.beginTransaction(transactionId);
        defer {
            changesObserver.endTransaction(transactionId);
        }
        logger.trace("transaction \(transactionId) - begin")
        try execute("BEGIN TRANSACTION;");
        do {
            let result = try block(self);
            logger.trace("transaction: \(transactionId) - commit")
            try execute("COMMIT TRANSACTION;");
            return result;
        } catch {
            logger.trace("transaction: \(transactionId) - rollback")
            try execute("ROLLBACK TRANSACTION;");
            throw error;
        }
    }
    
    private func statement(_ query: String, cached: Bool) throws -> Statement {
        guard cached else {
            return try Statement(connection: self.connection, query: query);
        }
        guard let stmt = self.statementsCache[query] else {
            let stmt = try Statement(connection: self.connection, query: query);
            self.statementsCache[query] = stmt;
            return stmt;
        }
        return stmt;
    }
    
    deinit {
        statementsCache.removeAll();
        sqlite3_close_v2(connection);
    }
    
    public func freeMemory() {
        statementsCache = [:];
    }
    
    public func changePublisher(for tableName: String) -> AnyPublisher<Change,Never> {
        return changesObserver.changePublisher(table: tableName);
    }
    
    func select(_ query: String, cached: Bool, params: [SQLValue]) throws -> [Row] {
        return try execute(query, cached: cached, params: params)
    }

    func select(_ query: String, cached: Bool, params: [String : SQLValue]) throws -> [Row] {
        return try execute(query, cached: cached, params: params);
    }

    func update(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try execute(query, cached: cached, params: params);
    }
    
    func update(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try execute(query, cached: cached, params: params);
    }
    
    func insert(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try execute(query, cached: cached, params: params);
    }
    
    func insert(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try execute(query, cached: cached, params: params);
    }
    
    func delete(_ query: String, cached: Bool, params: [String : SQLValue]) throws {
        try execute(query, cached: cached, params: params)
    }
    
    func delete(_ query: String, cached: Bool, params: [SQLValue]) throws {
        try execute(query, cached: cached, params: params)
    }
        
    func withTransaction<R>(_ block: (DatabaseWriter) throws -> R) throws -> R {
        return try transaction(block);
    }
        

}
