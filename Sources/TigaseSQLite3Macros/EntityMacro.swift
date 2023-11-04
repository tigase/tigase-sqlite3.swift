//
// EntityMacro.swift
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

struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

struct SimpleFixItMessage: FixItMessage {
    let message: String;
    let fixItID: MessageID;
}

func sqlValue(typeName: String, fieldName: String, exprSyntax element: ExprSyntax) -> ExprSyntax {
    if let memberAccessExpr = element.as(MemberAccessExprSyntax.self), memberAccessExpr.base == nil {
        return ExprSyntax("try SQLValue.fromAny(\(raw: typeName).FieldTypes.\(raw: fieldName)\(element))");
    } else {
        return ExprSyntax("try SQLValue.fromAny(\(element))");
    }
}

public enum EntityMacroError: String, CustomStringConvertible, Error {
    case onlyApplicableToFinalClass
    case unsupportedFieldType
    
    public var description: String {
        switch self{
        case .unsupportedFieldType:
            return "Unsupported field type!"
        case .onlyApplicableToFinalClass:
            return "@Entity can only be applied to final class"
        }
    }
    
    var messageId: MessageID {
        return MessageID(domain: "QueryMacroError", id: rawValue)
    }
    
    var severity: DiagnosticSeverity {
        return .error;
    }
    
    var message: DiagnosticMessage {
        return SimpleDiagnosticMessage(message: description, diagnosticID: messageId, severity: severity)
    }
}

public struct EntityMacro: MemberMacro, ExtensionMacro {
    
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration as? ClassDeclSyntax, classDecl.modifiers.contains(where: { $0.name.text == "final" }) else {
            throw EntityMacroError.onlyApplicableToFinalClass;
        }
        if !(classDecl.inheritanceClause?.inheritedTypes.contains(where: { $0.as(InheritedTypeSyntax.self)?.type.as(IdentifierTypeSyntax.self)?.name.text == "SQLCodable" }) ?? false) {
            return [try ExtensionDeclSyntax("extension \(type): SQLCodable {}")]
        }
        return [];
    }
        
    public struct RelationDef {
        let propertyName: String;
        let type: TypeSyntax;
        let externalJoinProperty: String;
    }
    
    public static func expansion<
        Declaration: DeclGroupSyntax,
        Context: MacroExpansionContext
      >(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        in context: Context
      ) throws -> [DeclSyntax] {
          print(node.debugDescription);
          let columnNameFormat = ColumnNameFormat(rawValue: node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "columnNames" })?.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text ?? "") ?? .snakeCase;
          guard let classDecl = declaration as? ClassDeclSyntax, classDecl.modifiers.contains(where: { $0.name.text == "final" }) else {
              throw EntityMacroError.onlyApplicableToFinalClass;
          }
                    
          let typeName = classDecl.name.text;
          let relations = entityFields(declaration: classDecl).compactMap({ fieldDecl -> RelationDef? in
              guard let propertyName = fieldDecl.name else {
                  return nil;
              }

              guard let type = fieldDecl.bindings.first?.typeAnnotation?.type.as(ArrayTypeSyntax.self)?.element.as(TypeSyntax.self) else {
                  return nil;
              }

              guard let externalField = fieldDecl.relationExternalField() else {
                  return nil;
              }
              
              return .init(propertyName: propertyName, type: type, externalJoinProperty: externalField)
          })
          
          let results: [[DeclSyntaxProtocol]] = [
            try initMethod(declaration: classDecl, context: context),
            try initFromModel(declaration: classDecl, typeName: typeName),
            staticFieldsField(declaration: classDecl, typeName: typeName, columnNameFormat: columnNameFormat),
            try staticFieldTypes(declaration: classDecl, typeName: typeName),
            staticRelationTablesField(declaration: classDecl, relations: relations),
            try staticLoadRelationsMethod(declaration: classDecl, typeName: typeName, relations: relations),
            try staticInsertMethod(declaration: classDecl, context: context),
            try insertMethod(declaration: classDecl, typeName: typeName),
            try staticDeleteMethod(declaration: classDecl),
            try deleteMethod(declaration: classDecl)
          ];

        return results.flatMap({ items in
            return items.map({ DeclSyntax($0) })
        });
      }
    
    static func staticLoadRelationsMethod(declaration: ClassDeclSyntax, typeName: String, relations: [RelationDef]) throws -> [FunctionDeclSyntax] {
        guard !hasMethod(declaration: declaration, name: "loadRelations", parameters: ["from database", "for items"], isStatic: true) else {
            return [];
        }
        return [try FunctionDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic), name: TokenSyntax(stringLiteral: "loadRelations"), signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax() {
            FunctionParameterSyntax(firstName: "from database", colon: ":", type: TypeSyntax(stringLiteral: "DatabaseReader"))
            FunctionParameterSyntax(firstName: "for items", colon: ":", type: TypeSyntax(stringLiteral: "[\(typeName)]"))
        }, effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsSpecifier: TokenSyntax(stringLiteral: "throws"))), bodyBuilder: {
            for relation in relations {
                VariableDeclSyntax(bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
                    PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "\(raw: relation.propertyName)"), typeAnnotation: TypeAnnotationSyntax(type: ArrayTypeSyntax(element: relation.type)), initializer: InitializerClauseSyntax(value: ExprSyntax("try database.select(where: .literal(\"\\(\(raw: relation.type).keyPathToColumnName(for: \\.\(raw: relation.externalJoinProperty))) IN (\\(items.map(\\.id).map({ $0.description }).joined(separator: \", \")))\"))")))
                }))
                VariableDeclSyntax(bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
                    PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "\(raw: relation.propertyName)ById"), initializer: InitializerClauseSyntax(value: ExprSyntax("Dictionary(grouping: \(raw: relation.propertyName), by: { $0.\(raw: relation.externalJoinProperty) })")))
                }));
                try ForStmtSyntax("for item in items", bodyBuilder: {
                    ExprSyntax("item.\(raw: relation.propertyName) = \(raw: relation.propertyName)ById[item.id] ?? []")
                })
            }
        })];
    }
    
    static func staticRelationTablesField(declaration: ClassDeclSyntax, relations: [RelationDef]) -> [VariableDeclSyntax] {
        guard !hasField(declaration: declaration, name: "relationTables", isStatic: true) else {
            return [];
        }
        let relationTables = relations.map({ ExprSyntax("\($0.type).tableName") }).map({ ArrayElementSyntax(expression: $0) })
        return [VariableDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic),bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
            PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "relationTables"), typeAnnotation: TypeAnnotationSyntax(type: ArrayTypeSyntax(element: TypeSyntax(stringLiteral: "String"))), initializer: InitializerClauseSyntax(value: ArrayExprSyntax(elements: ArrayElementListSyntax(relationTables))))
        }))]
    }
    
    static func insertMethod(declaration: ClassDeclSyntax, typeName: String) throws -> [FunctionDeclSyntax] {
        guard !hasMethod(declaration: declaration, name: "insert", parameters: ["into database"], isStatic: false) else {
            return [];
        }
        let paramsList = entityFields(declaration: declaration)
            .filter({ !$0.hasMacro(.Autogenerated) })
            .filter({ !$0.hasMacro(.Relation) })
            .compactMap({ $0.name })
            .map({field in ".value(\\.\(field), value: self.\(field))" })
        return [FunctionDeclSyntax(modifiers: modifiers(isStatic: false, isPublic: declaration.isPublic), name: TokenSyntax(stringLiteral: "insert"), signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax() {
            FunctionParameterSyntax(firstName: "into database", colon: ":", type: TypeSyntax(stringLiteral: "DatabaseWriter"))
        }, effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsSpecifier: TokenSyntax(stringLiteral: "throws"))), bodyBuilder: {
            VariableDeclSyntax(bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
                PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "params"), typeAnnotation: TypeAnnotationSyntax(type: ArrayTypeSyntax(element: TypeSyntax(stringLiteral: "ModelInsertExpression<\(typeName)>"))), initializer: InitializerClauseSyntax(value: ExprSyntax("[\(raw: paramsList.joined(separator: ","))]")))
            }));
            ExprSyntax("try database.insert(\(raw: typeName).self, values: params)")
        })];
    }
        
    static func initMethod(declaration: ClassDeclSyntax, context: MacroExpansionContext) throws -> [InitializerDeclSyntax] {
        let initFields = entityFields(declaration: declaration).compactMap({ fieldDecl -> (String,TypeSyntax,ExprSyntax?,Bool,VariableDeclSyntax)? in
            guard let propertyName = fieldDecl.name, let type = fieldDecl.bindings.first?.typeAnnotation?.type else {
                return nil;
            }
            
            let defValue = fieldDecl.bindings.first?.initializer?.as(InitializerClauseSyntax.self)?.value;
            return (propertyName,type, defValue, fieldDecl.hasMacro(.Autogenerated), fieldDecl);
        })
        guard !hasInit(declaration: declaration, parameters: initFields.map({ $0.0 })) else {
            return [];
        }
        let params = initFields.compactMap({ field -> String? in
            if let defValue = field.2 {
                return "\(field.0): \(field.1) = \(defValue.description)"
            } else if (field.1.is(OptionalTypeSyntax.self)) {
                return "\(field.0): \(field.1) = nil"
            } else if field.1.is(ArrayTypeSyntax.self) {
                return "\(field.0): \(field.1) = []";
            } else if field.1.as(IdentifierTypeSyntax.self) != nil {
                if (field.3) {
                    return "\(field.0): \(field.1) = -1"
                } else {
                    return "\(field.0): \(field.1)"
                }
            } else {
                context.diagnose(.init(node: Syntax(field.4), message: EntityMacroError.unsupportedFieldType.message, highlights: [Syntax(field.4)]))
                return nil;
            }
        });
        let visibility = declaration.isPublic ? "public " : "";
        return [try InitializerDeclSyntax("\(raw: visibility)init(\(raw: params.joined(separator: ", ")))") {
            CodeBlockItemListSyntax {
                for param in initFields {
                    ExprSyntax("self.\(raw: param.0) = \(raw: param.0);")
                }
            }
        }];
    }
    
    static func staticInsertMethod(declaration: ClassDeclSyntax, context: MacroExpansionContext) throws -> [FunctionDeclSyntax] {
        let insertFields = entityFields(declaration: declaration)
            .filter({ !$0.hasMacro(.Relation) })
            .filter({ !$0.hasMacro(.Autogenerated) })
            .compactMap({ fieldDecl -> (String,TypeSyntax,ExprSyntax?,VariableDeclSyntax)? in
                guard let propertyName = fieldDecl.name, let type = fieldDecl.bindings.first?.typeAnnotation?.type else {
                return nil;
            }
            
            let defValue = fieldDecl.bindings.first?.initializer?.as(InitializerClauseSyntax.self)?.value;
            return (propertyName,type, defValue, fieldDecl);
        })

        guard !hasMethod(declaration: declaration, name: "insert", parameters: ["into database"] + insertFields.map({ $0.0 }), isStatic: false) else {
            return [];
        }
        
        let params = insertFields.compactMap({ field -> String? in
            if let defValue = field.2 {
                return "\(field.0): \(field.1) = \(defValue.description)"
            } else if (field.1.is(OptionalTypeSyntax.self)) {
                return "\(field.0): \(field.1) = nil"
            } else if field.1.is(ArrayTypeSyntax.self) {
                return "\(field.0): \(field.1) = []";
            } else if field.1.as(IdentifierTypeSyntax.self) != nil {
                return "\(field.0): \(field.1)"
            } else {
                context.diagnose(.init(node: Syntax(field.3), message: EntityMacroError.unsupportedFieldType.message, highlights: [Syntax(field.3)]))
                return nil;
            }
        });
        let paramsList = insertFields.map({ $0.0 }).map({field in ".value(\\.\(field), value: \(field))" });
        
        return [FunctionDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic), name: TokenSyntax(stringLiteral: "insert"), signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax() {
            FunctionParameterSyntax(stringLiteral: "into database: DatabaseWriter")
            for param in params {
                FunctionParameterSyntax(stringLiteral: param)
            }
        }),effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsSpecifier: TokenSyntax(stringLiteral: "throws")))) {
            CodeBlockItemListSyntax {
                ExprSyntax("try database.insert(\(raw: declaration.name.text).self, values: [\(raw: paramsList.joined(separator: ", "))])")
            }
        }];
    }
    
    static func staticDeleteMethod(declaration: ClassDeclSyntax) throws -> [FunctionDeclSyntax] {
        let primaryKeys = entityFields(declaration: declaration)
            .filter({ !$0.hasMacro(.Relation) })
            .filter({ $0.hasMacro(.PrimaryKey) })
            .compactMap({ fieldDecl -> (String,TypeSyntax,ExprSyntax?)? in
                guard let propertyName = fieldDecl.name, let type = fieldDecl.bindings.first?.typeAnnotation?.type else {
                return nil;
            }
            
            let defValue = fieldDecl.bindings.first?.initializer?.as(InitializerClauseSyntax.self)?.value;
            
            return (propertyName,type, defValue);
        })
                
        guard !hasMethod(declaration: declaration, name: "delete", parameters: ["from database"] + primaryKeys.map({ $0.0 }), isStatic: true) else {
            return [];
        }
        
        let params = primaryKeys.map({ field -> String in
            return "\(field.0): \(field.1)"
        });

        let paramsList = primaryKeys.map({ $0.0 }).map({field in ".equals(\\.\(field), value: \(field))" });
        return [FunctionDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic), name: TokenSyntax(stringLiteral: "delete"), signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax() {
            FunctionParameterSyntax(stringLiteral: "from database: DatabaseWriter")
            for param in params {
                FunctionParameterSyntax(stringLiteral: param)
            }
        }), effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsSpecifier: TokenSyntax(stringLiteral: "throws")))) {
            CodeBlockItemListSyntax {
                ExprSyntax("try database.delete(\(raw: declaration.name.text).self, where: .and(\(raw: paramsList.joined(separator: ", "))))")
            }
        }]
    }
    
    static func deleteMethod(declaration: ClassDeclSyntax) throws -> [FunctionDeclSyntax] {
        guard !hasMethod(declaration: declaration, name: "delete", parameters: ["from database"], isStatic: true) else {
            return [];
        }
        
        let primaryKeys = entityFields(declaration: declaration)
            .filter({ !$0.hasMacro(.Relation) })
            .filter({ $0.hasMacro(.PrimaryKey) })
            .compactMap({ fieldDecl -> (String,TypeSyntax,ExprSyntax?)? in
                guard let propertyName = fieldDecl.name, let type = fieldDecl.bindings.first?.typeAnnotation?.type else {
                return nil;
            }
            
            let defValue = fieldDecl.bindings.first?.initializer?.as(InitializerClauseSyntax.self)?.value;
            
            return (propertyName,type, defValue);
        })
        
        let paramsList = primaryKeys.map({ $0.0 }).map({field in ".equals(\\.\(field), value: self.\(field))" });
        return [FunctionDeclSyntax(modifiers: modifiers(isStatic: false, isPublic: declaration.isPublic), name: TokenSyntax(stringLiteral: "delete"), signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax() {
            FunctionParameterSyntax(stringLiteral: "from database: DatabaseWriter")
        }), effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsSpecifier: TokenSyntax(stringLiteral: "throws")))) {
            CodeBlockItemListSyntax {
                ExprSyntax("try database.delete(\(raw: declaration.name.text).self, where: .and(\(raw: paramsList.joined(separator: ", "))))")
            }
        }]
    }
    
    
    static func entityFields(declaration: ClassDeclSyntax) -> [VariableDeclSyntax] {
        return declaration.memberBlock.members.compactMap({ member -> VariableDeclSyntax? in
            guard let fieldDecl = member.decl.as(VariableDeclSyntax.self), !fieldDecl.isStatic, fieldDecl.bindings.first?.accessorBlock == nil else {
                return nil;
            }
            return fieldDecl;
        })
    }
    
    static func hasField(declaration: ClassDeclSyntax, name: String, isStatic: Bool) -> Bool {
        return declaration.memberBlock.members.contains(where: { member in
            guard let fieldDecl = member.decl.as(VariableDeclSyntax.self), fieldDecl.isStatic == isStatic else {
                return false;
            }
            return fieldDecl.name == name;
        })
    }
    
    static func hasMethod(declaration: ClassDeclSyntax, name: String, parameters: [String], isStatic: Bool) -> Bool {
        return declaration.memberBlock.members.contains(where: { member in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self), funcDecl.isStatic == isStatic else {
                return false;
            }
            
            guard funcDecl.name.text == name else {
                return false;
            }
            
            return funcDecl.signature.parameterClause.parameters.map({ $0.firstName.text }) == parameters;
        })
    }
    
    static func hasInit(declaration: ClassDeclSyntax, parameters: [String]) -> Bool {
        return declaration.memberBlock.members.contains(where: { member in
            guard let funcDecl = member.decl.as(InitializerDeclSyntax.self) else {
                return false;
            }
                        
            return funcDecl.signature.parameterClause.parameters.map({ $0.firstName.text }) == parameters;
        })
    }

    static func modifiers(isStatic: Bool, isPublic: Bool) -> DeclModifierListSyntax {
        var modifiers: [String] = [];
        if isPublic {
            modifiers.append("public");
        }
        if isStatic {
            modifiers.append("static");
        }
        guard !modifiers.isEmpty else {
            return DeclModifierListSyntax();
        }
        return DeclModifierListSyntax() {
            for modifier in modifiers {
                DeclModifierSyntax(name: TokenSyntax(stringLiteral: modifier))
            }
        }
    }
    
    static func initFromModel(declaration: ClassDeclSyntax, typeName: String) throws -> [InitializerDeclSyntax] {
        guard !hasInit(declaration: declaration, parameters: ["model"]) else {
            return [];
        }
        let initFieldsNames = entityFields(declaration: declaration)
            .filter({ !$0.isStatic })
            .filter({ !$0.hasMacro(.Relation) })
            .compactMap({ $0.name })
        
        let visibility = declaration.isPublic ? "public " : "";
        
        return [try InitializerDeclSyntax("\(raw: visibility)init(model: ModelRow<\(raw: typeName)>)") {
            CodeBlockItemListSyntax {
                for name in initFieldsNames {
                    ExprSyntax("self.\(raw: name) = model[\\.\(raw: name)];")
                }
            }
        }]
    }
    
    static func staticFieldTypes(declaration: ClassDeclSyntax, typeName: String) throws -> [StructDeclSyntax] {
        let fieldsExpressions = declaration.memberBlock.members.compactMap({ member -> VariableDeclSyntax? in
            guard let fieldDecl = member.decl.as(VariableDeclSyntax.self), !fieldDecl.isStatic, fieldDecl.bindings.first?.accessorBlock == nil, let propertyName = fieldDecl.name else {
                return nil;
            }
            
            guard let type = fieldDecl.bindings.first?.typeAnnotation?.type, let fieldType = (type.as(OptionalTypeSyntax.self)?.wrappedType ?? type)?.description else {
                return nil;
            }
                        
            let valueExpr = ExprSyntax("\(raw: fieldType).self");
            return VariableDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic), bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
                PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "\(raw: propertyName)"), initializer: InitializerClauseSyntax(value: valueExpr))
            }))
        });
        
        return [StructDeclSyntax(name: "FieldTypes", memberBlock: MemberBlockSyntax(membersBuilder: {
            for field in fieldsExpressions {
                field;
            }
        }))]
    }
    
    static func staticFieldsField(declaration: ClassDeclSyntax, typeName: String, columnNameFormat: ColumnNameFormat) -> [VariableDeclSyntax] {
        guard !hasField(declaration: declaration, name: "fields", isStatic: true) else {
            return [];
        }
        let fieldsExpressions = declaration.memberBlock.members.compactMap({ member -> ExprSyntax? in
            guard let fieldDecl = member.decl.as(VariableDeclSyntax.self), !fieldDecl.isStatic, fieldDecl.bindings.first?.accessorBlock == nil, let propertyName = fieldDecl.name else {
                return nil;
            }
            if let columnName = fieldDecl.sqlColumnName() {
                return ExprSyntax(".init(\\.\(raw: propertyName), column: \(raw: columnName))");
            } else {
                switch columnNameFormat {
                case .camelCase:
                    return ExprSyntax(".init(\\.\(raw: propertyName), column: \"\(raw: propertyName)\")");
                case .snakeCase:
                    let regex = try! NSRegularExpression(pattern: "([a-z0-9])([A-Z])", options: []);
                    let range = NSRange(location: 0, length: propertyName.count);
                    let columnName = regex.stringByReplacingMatches(in: propertyName, options: [], range: range, withTemplate: "$1_$2").lowercased();
                    print("formatted name: \(columnName)")
                    return ExprSyntax(".init(\\.\(raw: propertyName), column: \"\(raw: columnName)\")");
                }
            }
        });
        
        let valueExpr = ExprSyntax("[\(raw: fieldsExpressions.map({ $0.description }).joined(separator: ", "))]")
        
        return [VariableDeclSyntax(modifiers: modifiers(isStatic: true, isPublic: declaration.isPublic), bindingSpecifier: "let", bindings: PatternBindingListSyntax(itemsBuilder: {
            PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: "fields"), typeAnnotation: TypeAnnotationSyntax(type: ArrayTypeSyntax(element: TypeSyntax(stringLiteral: "SQLField<\(typeName)>"))), initializer: InitializerClauseSyntax(value: valueExpr))
        }))]
    }
    
}

public enum ColumnNameFormat: String {
    case camelCase
    case snakeCase
}

protocol ModifierAwareProtocol {

    var modifiers: DeclModifierListSyntax { get }
}

extension ModifierAwareProtocol {
    
    var isPublic: Bool {
        modifiers.contains(where: { $0.name.text == "public" })
    }
    
    var isStatic: Bool {
        modifiers.contains(where: { $0.name.text == "static" })
    }
    
}

enum Macros: String {
    case PrimaryKey
    case Autogenerated
    case Column
    case Relation
}

extension VariableDeclSyntax {
    var name: String? {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
    
    func hasMacro(_ macro: Macros) -> Bool {
        return attributes.contains(where: { el in
            return el.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.description == macro.rawValue;
        });
    }
    
    func macro(_ macro: Macros) -> AttributeSyntax? {
        return attributes.first(where: { el in
            return el.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.description == macro.rawValue;
        })?.as(AttributeSyntax.self);
    }
    
    func sqlColumnName() -> String? {
        guard let columnMacro = macro(.Column) else {
            return nil;
        }
                
        guard let sqlColumnName = columnMacro.arguments?.as(LabeledExprListSyntax.self)?.first?.expression else {
            return nil;
        }
        return sqlColumnName.description;
    }
    
    func relationExternalField() -> String? {
        guard let columnMacro = macro(.Relation) else {
            return nil;
        }
                
        guard let fieldName = columnMacro.arguments?.as(LabeledExprListSyntax.self)?.first?.expression.as(StringLiteralExprSyntax.self)?.segments else {
            return nil;
        }
        return fieldName.description;
    }
    
}

extension FunctionDeclSyntax: ModifierAwareProtocol {}

extension VariableDeclSyntax: ModifierAwareProtocol {}
extension ClassDeclSyntax: ModifierAwareProtocol {}
