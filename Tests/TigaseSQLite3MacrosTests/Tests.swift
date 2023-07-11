//
// Tests.swift
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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import TigaseSQLite3Macros
import XCTest

final class EntityMacroTests: XCTestCase {

    func test() {
        let source: SourceFileSyntax =
            """
            @EntityMacro
            final class Test {
            
                var debugDescription: String {
                    return "test!";
                }
            
                @Autogenerated
                @Column
                let id: Int;
                @Column
                var name: String = "";
                @Column("my_data")
                var myData: String?;
                @Relation("testId","test_id")
                var attachments: [String] = ["test"];
                        
                init() {}
                func test() -> String {
                    return "";
                }
            }
            """


        let file = BasicMacroExpansionContext.KnownSourceFile(
            moduleName: "MyModule",
            fullFilePath: "test.swift"
        )
        
        let context = BasicMacroExpansionContext(sourceFiles: [source: file]);
        let transformed = source.expand(macros: ["EntityMacro":EntityMacro.self,"Column": ColumnMacro.self], in: context);
        print("transformed:\n\(transformed.debugDescription)")
        //precondition(transformed.description == "");
    }
    
    func test2() {
        let source: SourceFileSyntax =
            """
            #update<Test>{ x in x.name = "test"; x.name = "test2";
                x.date = temp ?? .now;
            }
            """


        let file = BasicMacroExpansionContext.KnownSourceFile(
            moduleName: "MyModule",
            fullFilePath: "test.swift"
        )
        
        let context = BasicMacroExpansionContext(sourceFiles: [source: file]);
        let transformed = source.expand(macros: ["update":UpdateMacro.self], in: context);
        print("transformed:\n\(transformed.description)")
        //precondition(transformed.description == "");
    }
    
    func test3() {
        let source: SourceFileSyntax =
            """
            let query: ModelQuery<Test> = #query<Test>{ x -> Bool in return x.name == "test" && x.test == "data" && (x.createdAt ?? .now == .now || x.createdAt ?? x.test == xyw.test.now) }
            """


        let file = BasicMacroExpansionContext.KnownSourceFile(
            moduleName: "MyModule",
            fullFilePath: "test.swift"
        )
        
        let context = BasicMacroExpansionContext(sourceFiles: [source: file]);
        let transformed = source.expand(macros: ["query":QueryMacro.self], in: context);
        print("transformed:\n\(transformed.description)")
        //precondition(transformed.description == "");
    }
}
