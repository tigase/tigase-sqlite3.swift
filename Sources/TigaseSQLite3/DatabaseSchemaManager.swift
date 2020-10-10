//
//  File.swift
//  
//
//  Created by Andrzej Wójcik on 08/10/2020.
//

import Foundation

public class DatabaseSchemaManager {
    
    public init() {
    }
    
    public func schemaVersion(database: DatabaseWriter) throws -> Int {
        return try database.select("PRAGMA user_version", cached: false).mapFirst({ $0.int(at: 0) })!;
    }
    
    public func schemaVersion(database: DatabaseWriter, newVersion: Int) throws {
        try database.execute("PRAGMA user_version = \(newVersion)");
    }
    
    public func upgrade(database: DatabaseWriter, migrator: DatabaseSchemaMigrator) throws {
        var currentVersion = try schemaVersion(database: database);
        while currentVersion < migrator.expectedVersion {
            try database.withTransaction({ database in
                try migrator.upgrade(database: database, newVersion: currentVersion + 1);
                try self.schemaVersion(database: database, newVersion: currentVersion + 1);
            })
            currentVersion = try schemaVersion(database: database);
        }
    }
    
}

public protocol DatabaseSchemaMigrator {
    
    var expectedVersion: Int { get }
    
    func upgrade(database: DatabaseWriter, newVersion: Int) throws;
    
}
