//
// RelationMacro.swift
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

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

enum RelationMacroError: CustomStringConvertible, Error {
    case notVariable
    case notOnStatic
    case onlyArrays
    
    var description: String {
        switch self {
        case .notVariable:
            return "@Relation may only be used on properties of a class"
        case .notOnStatic:
            return "@Relation cannot be used on a static property"
        case .onlyArrays:
            return "@Relation supports only properties of type `Array<X>`"
        }
    }
}

public struct RelationMacro: PeerMacro {
    
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw RelationMacroError.notVariable;
        }
        
        guard !varDecl.isStatic else {
            throw RelationMacroError.notOnStatic;
        }
        
        guard varDecl.bindings.first?.typeAnnotation?.type.as(ArrayTypeSyntax.self) != nil else {
            throw RelationMacroError.onlyArrays;
        }
        return [];
    }
    
}
