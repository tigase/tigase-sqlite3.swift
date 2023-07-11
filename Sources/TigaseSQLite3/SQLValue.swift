//
// SQLValue.swift
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

public protocol StringRawRepresentable {
    
    var rawValue: String { get }

    init?(rawValue: String)
    
}

public protocol IntRawRepresentable {
    
    var rawValue: Int { get }

    init?(rawValue: Int)
    
}

public enum SQLValue: CustomStringConvertible, Equatable {
    
    case null
    case integer(Int)
    case double(Double)
    case text(String)
    case blob(Data)

    public static func fromAny(_ value: Encodable?) throws -> SQLValue {
        guard let value else { return .null }
        
        switch value {
        case let v as Int:
            return .integer(v)
        case let v as Double:
            return .double(v)
        case let v as String:
            return .text(v);
        case let v as Data:
            return .blob(v)
        case let v as Date:
            return .integer(Int(v.timeIntervalSince1970 * 1000));
        case let v as IntRawRepresentable:
            return .integer(v.rawValue)
        case let v as StringRawRepresentable:
            return .text(v.rawValue)
        case let v as LosslessStringConvertible:
            return .text(v.description);
        default:
            return .text(String(data: try JSONEncoder().encode(value), encoding: .utf8)!)
        }
    }
    
    public static func fromAny<V: Encodable>(_ value: V?) throws -> SQLValue {
        guard let value else { return .null }
        
        switch value {
        case let v as Int:
            return .integer(v)
        case let v as Double:
            return .double(v)
        case let v as String:
            return .text(v);
        case let v as Data:
            return .blob(v)
        case let v as Date:
            return .integer(Int(v.timeIntervalSince1970 * 1000));
        case let v as IntRawRepresentable:
            return .integer(v.rawValue)
        case let v as StringRawRepresentable:
            return .text(v.rawValue)
        case let v as LosslessStringConvertible:
            return .text(v.description);
        default:
            return .text(String(data: try JSONEncoder().encode(value), encoding: .utf8)!)
        }
    }
    
    public func value<V: Decodable>() throws -> V? {
        switch V.self {
        case is Int.Type:
            return self.int as? V;
        case is Double.Type:
            return self.double as? V;
        case is String.Type:
            return self.string as? V;
        case is Data.Type:
            return self.data as? V;
        case is Date.Type:
            return self.date as? V;
        case let type as IntRawRepresentable.Type:
            guard let value = self.int else { return nil }
            return type.init(rawValue: value) as? V;
        case let type as StringRawRepresentable.Type:
            guard let value = self.string else { return nil }
            return type.init(rawValue: value) as? V;
        case let type as LosslessStringConvertible.Type:
            guard let value = self.string else {
                return nil;
            }
            return type.init(value) as? V;
        default:
            guard let value = self.string else {
                return nil;
            }
            return try? JSONDecoder().decode(V.self, from: value.data(using: .utf8)!);
        }
    }
    
    public var description: String {
        switch self {
        case .blob(let data):
            return "0x\(data.map({ String(format: "%02hhx", $0) }).joined())";
        case .text(let text):
            return "\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\"";
        case .double(let value):
            return String(value);
        case .integer(let value):
            return String(value);
        case .null:
            return "null";
        }
    }
    
    public var double: Double? {
        switch self {
        case .double(let value):
            return value;
        default:
            return nil;
        }
    }
    
    public var int: Int? {
        switch self {
        case .integer(let value):
            return value;
        default:
            return nil;
        }
    }

    public var string: String? {
        switch self {
        case .text(let value):
            return value;
        default:
            return nil;
        }
    }
    
    public var data: Data? {
        switch self {
        case .text(let value):
            return value.data(using: .utf8)
        case .blob(let value):
            return value;
        default:
            return nil;
        }
    }
    
    public var date: Date? {
        switch self {
        case .integer(let value):
            return Date(timeIntervalSince1970: Double(value)/1000);
        default:
            return nil;
        }
    }


}
