//
// UpdateMacro.swift
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

public enum UpdateMacroError: CustomStringConvertible, Error {
    case missingTrailigClosure
    case missingGenericTypeParameter
    case onlyAssignmentsAreAllowed
    case unsupportedBinaryOperator(String)
    case invalidParameter
    case duplicatedAssignmentForField(String)
        
    public var description: String {
        switch self {
        case .missingTrailigClosure:
            return "#Update macro requires trailing closure!";
        case .missingGenericTypeParameter:
            return "Missing generic type parameter!"
        case .onlyAssignmentsAreAllowed:
            return "Only assignment statements to entity members are allowed!"
        case .unsupportedBinaryOperator(let val):
            return "Unsupported binary operator '\(val)'"
        case .invalidParameter:
            return "Invalid parameter"
        case .duplicatedAssignmentForField(let val):
            return "Duplicated assignment for '\(val)' field";
        }
    }
    
    var id: String {
        switch self {
        case .missingTrailigClosure:
            return "missingTrailigClosure"
        case .missingGenericTypeParameter:
            return "missingGenericTypeParameter"
        case .onlyAssignmentsAreAllowed:
            return "onlyAssignmentsAreAllowed"
        case .unsupportedBinaryOperator(_):
            return "unsupportedBinaryOperator"
        case .invalidParameter:
            return "invalidParameter"
        case .duplicatedAssignmentForField(_):
            return "duplicatedAssignmentForField"
        }
    }
    
    var messageId: MessageID {
        return MessageID(domain: "UpdateMacroError", id: id)
    }
    
    var severity: DiagnosticSeverity {
        return .error;
    }
    
    var message: DiagnosticMessage {
        return SimpleDiagnosticMessage(message: description, diagnosticID: messageId, severity: severity)
    }
}

public struct UpdateMacro: ExpressionMacro {
    
    public static func expansion<Node, Context>(of node: Node, in context: Context) throws -> SwiftSyntax.ExprSyntax where Node : SwiftSyntax.FreestandingMacroExpansionSyntax, Context : SwiftSyntaxMacros.MacroExpansionContext {
        guard let macroExpr = node.as(MacroExpansionExprSyntax.self), let closure = macroExpr.trailingClosure else {
            throw UpdateMacroError.missingTrailigClosure;
        }
                    
        guard let typeName = macroExpr.genericArguments?.arguments.first?.argumentType.as(SimpleTypeIdentifierSyntax.self)?.name.text else {
            throw UpdateMacroError.missingGenericTypeParameter;
        }
        
        let entityVariable = closure.signature?.input?.as(ClosureParamListSyntax.self)?.first?.name.text ?? "$0";        
        let statements = closure.statements;
        var queryParts: [String] = [];
        var params: [ExprSyntax] = [];
        var setFields: Set<String> = [];
        for statement in statements {
            var elements = try getExpressions(item: statement.item, context: context);
            if elements.isEmpty {
                continue;
            }
            
            guard let assignMemberExpr = elements.removeFirst().as(MemberAccessExprSyntax.self), assignMemberExpr.base?.as(IdentifierExprSyntax.self)?.identifier.text == entityVariable else {
                context.diagnose(.init(node: Syntax(statement), message: UpdateMacroError.onlyAssignmentsAreAllowed.message, highlights: [Syntax(statement)]));
                continue;
            }
            
            let fieldName = assignMemberExpr.name.text;
            
            guard let assignOperation = elements.removeFirst().as(AssignmentExprSyntax.self), assignOperation.assignToken.text == "=" else {
                context.diagnose(.init(node: Syntax(statement), message: UpdateMacroError.onlyAssignmentsAreAllowed.message, highlights: [Syntax(statement)]));
                continue;
            }
            
            if setFields.contains(fieldName) {
                context.diagnose(.init(node: Syntax(statement), message: UpdateMacroError.duplicatedAssignmentForField(fieldName).message, highlights: [Syntax(statement)]));
            }
            setFields.insert(fieldName);
            
            elements = elements.map({ expr in
                if let member = expr.as(MemberAccessExprSyntax.self), member.base == nil {
                    return member.with(\.base, ExprSyntax("\(raw: typeName).FieldTypes.\(raw: assignMemberExpr.name.text)")).as(ExprSyntax.self)!;
                } else {
                    return expr;
                }
            })
            
            queryParts.append(fieldName);
            params.append(sqlValue(typeName: typeName, fieldName: fieldName, exprSyntax: SequenceExprSyntax(elements: ExprListSyntax(elements)).as(ExprSyntax.self)!));
        }

        let arr = ArrayExprSyntax(expressions: params);
        return ExprSyntax("[.generated(query: \"\(raw: queryParts.map({ "\\(\(typeName).keyPathToColumnName(for: \\.\($0))) = ?" }).joined(separator: ","))\", params: \(raw: arr.description))]")
    }
        
    private static func getExpressions(item: SyntaxProtocol, context: MacroExpansionContext) throws -> [ExprSyntax] {
        if let infix = item.as(InfixOperatorExprSyntax.self) {
            return [infix.leftOperand, infix.operatorOperand, infix.rightOperand].compactMap({ $0 });
        }
        if let sequenceExprSyntax = item.as(SequenceExprSyntax.self) {
            return sequenceExprSyntax.elements.map({ $0 });
        }
        
        context.diagnose(.init(node: Syntax(item), message: UpdateMacroError.onlyAssignmentsAreAllowed.message, highlights: [Syntax(item)]));
        return [];
    }
}
