//
// QueryMacro.swift
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
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

enum QueryMacroError: CustomStringConvertible, Error {
    case missingTrailigClosure
    case missingGenericTypeParameter
    case onlySingleStatementExpressionsSupported
    case unsupportedOperator(String)
    case invalidParameter(Any)
        
    public var description: String {
        switch self {
        case .missingTrailigClosure:
            return "#Query macro requires trailing closure!";
        case .missingGenericTypeParameter:
            return "Missing generic type parameter!"
        case .onlySingleStatementExpressionsSupported:
            return "Only single statement expressions are supported!"
        case .unsupportedOperator(let val):
            return "Unsupported operator '\(val)'"
        case .invalidParameter(let val):
            return "invalid parameter: \(val)"
        }
    }
    
    var id: String {
        switch self {
        case .missingTrailigClosure:
            return "missingTrailigClosure"
        case .missingGenericTypeParameter:
            return "missingGenericTypeParameter";
        case .onlySingleStatementExpressionsSupported:
            return "onlySingleStatementExpressionsSupported"
        case .unsupportedOperator(_):
            return "unsupportedOperator"
        case .invalidParameter(_):
            return "invalidParameter";
        }
    }
    
    var messageId: MessageID {
        return MessageID(domain: "QueryMacroError", id: id)
    }
    
    var severity: DiagnosticSeverity {
        return .error;
    }
    
    var message: DiagnosticMessage {
        return SimpleDiagnosticMessage(message: description, diagnosticID: messageId, severity: severity)
    }
}

public struct QueryMacro: ExpressionMacro {
    
    public static func expansion<Node, Context>(of node: Node, in context: Context) throws -> SwiftSyntax.ExprSyntax where Node : SwiftSyntax.FreestandingMacroExpansionSyntax, Context : SwiftSyntaxMacros.MacroExpansionContext {
        guard let macroExpr = node.as(MacroExpansionExprSyntax.self), let closure = macroExpr.trailingClosure else {
            throw QueryMacroError.missingTrailigClosure;
        }
                    
        guard let typeName = macroExpr.genericArguments?.arguments.first?.argumentType.as(SimpleTypeIdentifierSyntax.self)?.name.text else {
            throw QueryMacroError.missingGenericTypeParameter;
        }
//
//        if closure.signature == nil{
//            let messageId = MessageID(domain: "test", id: "missing-parameter");
//            context.diagnose(.init(node: Syntax(closure), message: SimpleDiagnosticMessage(message: "Closure requires parameter!", diagnosticID: messageId, severity: .error), fixIts: [
//                FixIt(message: SimpleFixItMessage(message: "Closure requires parameter!", fixItID: messageId), changes: [
//                    FixIt.Change.replace(oldNode: Syntax(closure), newNode: Syntax(
//                        ExprSyntax("{ \(raw: typeName.first!.lowercased())\(raw: typeName.dropFirst()) -> Bool in \nreturn \n }").as(ClosureExprSyntax.self)!
//                    ))
//                ])
//            ]));
//        }
        
        let entityVariable = closure.signature?.input?.as(ClosureParamListSyntax.self)?.first?.name.text ?? "$0";
                        
        guard let statement = closure.statements.first, closure.statements.count == 1 else {
            throw QueryMacroError.onlySingleStatementExpressionsSupported;
        }

        let elements = try findClosureExpressionElements(item: statement.item);
        var queryParts: [String] = [];
        var params: [ExprSyntax] = [];
        try convert(typeName: typeName, elements: elements, entityVariable: entityVariable, queryParts: &queryParts, params: &params, context: context);
        let query = queryParts.joined(separator: " ");
        let arr = ArrayExprSyntax(expressions: params);
        return ExprSyntax(".generated(query: \"\(raw: query)\", params: \(arr))")
    }
    
    private static func findClosureExpressionElements(item: SyntaxProtocol) throws -> [ExprSyntax] {
        if let returnStmtSyntax = item.as(ReturnStmtSyntax.self) {
            guard let expression = returnStmtSyntax.expression else {
                throw QueryMacroError.invalidParameter(returnStmtSyntax);
            }
            return try findClosureExpressionElements(item: expression)
        }
        if let codeBlockItemSyntax = item.as(CodeBlockItemSyntax.self) {
            return try findClosureExpressionElements(item: codeBlockItemSyntax.item);
        }
        return try getExpressions(item: item);
    }
    
    private static func getExpressions(item: SyntaxProtocol) throws -> [ExprSyntax] {
        if let infix = item.as(InfixOperatorExprSyntax.self) {
            return [infix.leftOperand, infix.operatorOperand, infix.rightOperand].compactMap({ $0 });
        }
        if let sequenceExprSyntax = item.as(SequenceExprSyntax.self) {
            return sequenceExprSyntax.elements.map({ $0 });
        }
        
        throw QueryMacroError.invalidParameter(item)
    }
    
    struct Comparision {
        let memberAccess: MemberAccessExprSyntax;
        let operation: String;
        let expression: ExprSyntax;
    }
    
    public static func convert(typeName: String, elements: [ExprSyntax], entityVariable: String, queryParts: inout [String], params: inout [ExprSyntax], context: MacroExpansionContext) throws {
        var lastMember: MemberAccessExprSyntax?;
        var isCoalesce = false;
        for element in elements {
            let forcedValueElement = element.as(ForcedValueExprSyntax.self);
            if let memberAccess = (forcedValueElement?.expression ?? element).as(MemberAccessExprSyntax.self), memberAccess.base?.as(IdentifierExprSyntax.self)?.identifier.text == entityVariable {
                queryParts.append("\\(\(typeName).keyPathToColumnName(for: \\.\(memberAccess.name.text)))");
                lastMember = memberAccess;
            } else if let operation = element.as(BinaryOperatorExprSyntax.self) {
                if isCoalesce {
                    queryParts.append(")")
                    isCoalesce = false;
                }
                switch operation.operatorToken.text {
                case "==":
                    queryParts.append("=")
                case "<", "<=", ">=", ">":
                    queryParts.append(operation.operatorToken.text);
                case "!=":
                    queryParts.append("<>")
                case "&&":
                    queryParts.append("and");
                case "||":
                    queryParts.append("or")
                case "??":
                    isCoalesce = true;
                    let member = queryParts.removeLast();
                    queryParts.append("COALESCE(");
                    queryParts.append(member + ",");
                default:
                    context.diagnose(.init(node: Syntax(operation), message: QueryMacroError.unsupportedOperator(operation.operatorToken.text).message, highlights: [Syntax(operation)]));
                }
            } else if let tuple = element.as(TupleExprSyntax.self) {
                queryParts.append("(")
                for tupleExprElement in tuple.elements {
                    try convert(typeName: typeName, elements: try getExpressions(item: tupleExprElement.expression), entityVariable: entityVariable, queryParts: &queryParts, params: &params, context: context);
                }
                queryParts.append(")")
            } else if let infix = element.as(InfixOperatorExprSyntax.self) {
                try convert(typeName: typeName, elements: try getExpressions(item: infix), entityVariable: entityVariable, queryParts: &queryParts, params: &params, context: context);
            } else {
                if element.as(NilLiteralExprSyntax.self) != nil && queryParts.last == "=" {
                    queryParts.removeLast();
                    queryParts.append("is null");
                } else if element.as(NilLiteralExprSyntax.self) != nil && queryParts.last == "=" {
                    queryParts.removeLast();
                    queryParts.append("is not null");
                } else {
                    queryParts.append("?")
                    params.append(sqlValue(typeName: typeName, fieldName: lastMember!.name.text, exprSyntax: element));
                }
            }
        }
        if isCoalesce {
            queryParts.append(")")
        }
    }
}


//public struct EntityQueryExpression2: ExpressionMacro {
//    
//    public static func expansion<Node, Context>(of node: Node, in context: Context) throws -> SwiftSyntax.ExprSyntax where Node : SwiftSyntax.FreestandingMacroExpansionSyntax, Context : SwiftSyntaxMacros.MacroExpansionContext {
//        print(node.debugDescription)
//        guard let closure = node.argumentList.first?.expression.as(ClosureExprSyntax.self), let entityVariable = closure.signature?.input?.as(ClosureParamListSyntax.self)?.first?.name else {
//            throw EntitySetValuesError.invalidParameter(node);
//        }
//                
//        
//        print(closure.debugDescription);
//        
//        for statement in closure.statements {
//            print(statement.item.as(SequenceExprSyntax.self).debugDescription)
//            guard let elements = statement.item.as(SequenceExprSyntax.self)?.elements else {
//                throw EntitySetValuesError.invalidParameter(statement);
//            }
//            var query = "";
////            for element in elements {
////                try convert(element: element, entityVariable: entityVariable, query: &query, params: &params);
////            }
//            query = try convert(elements: elements, entityVariable: entityVariable);
//            print("sql query: \(query)")
////            let arr = ArrayExprSyntax(expressions: params);
////            print("sql params: [\(arr)]")
//        }
//        return ExprSyntax("1==1");
//    }
//    
//    struct Comparision {
//        let memberAccess: MemberAccessExprSyntax;
//        let operation: String;
//        let expression: ExprSyntax;
//    }
//    
//    static let JOINING_OPERATORS = Set(["&&","||"]);
//    static let OPERATIONS_MAPPING = [
//        "==": "equals",
//        "!=": "notEquals",
//        "<": "lessThan",
//        "<=": "lessThanOrEqual",
//        ">": "greaterThan",
//        ">=": "greaterThanOrEqual",
//        "!": "not"
//    ];
//    
//    public static func convert(elements: ExprListSyntax, entityVariable: TokenSyntax) throws -> String {
//        let operations = elements.compactMap({ $0.as(BinaryOperatorExprSyntax.self)?.operatorToken.text }).filter(JOINING_OPERATORS.contains(_:));
//        print("operations: \(operations)")
//        guard Set(operations).count <= 1 else {
//            throw EntitySetValuesError.invalidParameter(elements);
//        }
//        var sqlOperation: String? = operations.first;
//        //var query = "";
////        if let sqlOperation {
////            switch sqlOperation {
////            case "&&":
////                query = ".and(";
////            case "||":
////                query = ".or(";
////            }
////        }
//        var sqlOperations: [String] = [];
//        var lastMember: MemberAccessExprSyntax?;
//        var lastOperation: String?;
//        for element in elements {
//            print("element: \(element.debugDescription)")
//            if let memberAccess = element.as(MemberAccessExprSyntax.self), memberAccess.base?.as(IdentifierExprSyntax.self)?.identifier.text == entityVariable.text {
//                //query = "\(query) \(memberAccess.name.text)";
//                lastMember = memberAccess;
//            } else if let operation = element.as(BinaryOperatorExprSyntax.self) {
//                var comparison = operation.operatorToken.text;
//                if OPERATIONS_MAPPING[comparison] == nil {
//                    if !JOINING_OPERATORS.contains(comparison) {
//                        throw EntitySetValuesError.invalidParameter(operation.operatorToken);
//                    }
//                } else {
//                    lastOperation = comparison;
//                }
//            } else if let tuple = element.as(TupleExprSyntax.self) {
//                var subquery = "";
//                for tupleExprElement in tuple.elements {
//                    guard let sequence = tupleExprElement.expression.as(SequenceExprSyntax.self) else {
//                        throw EntitySetValuesError.invalidParameter(tuple);
//                    }
////                    for subelem in sequence.elements {
//                    sqlOperations.append(try convert(elements: sequence.elements, entityVariable: entityVariable));
////                    }
//                }
//                //query = "\(query) (\(subquery))";
//            } else {
//                print("value: \(element.debugDescription)")
//                let operation = OPERATIONS_MAPPING[lastOperation!]!;
//                sqlOperations.append(".\(operation)(\(lastMember!),\(element))")
//            }
//        }
//        print("operations: \(sqlOperations)")
//        if let sqlOperation {
//            return ".\(sqlOperation == "&&" ? "and" : "or")(\(sqlOperations.joined(separator: ",")))";
//        } else {
//            return sqlOperations.joined(separator: ",");
//        }
////        if let sqlOperation {
////            query = "\(query)"
////        }
//    }
//
////    public static func convert(element: ExprListSyntax.Element, entityVariable: TokenSyntax, query: inout String, params: inout [ExprSyntax]) throws {
////        if let memberAccess = element.as(MemberAccessExprSyntax.self), memberAccess.base?.as(IdentifierExprSyntax.self)?.identifier.text == entityVariable.text {
////            query = "\(query) \(memberAccess.name.text)";
////        } else if let operation = element.as(BinaryOperatorExprSyntax.self) {
////            switch operation.operatorToken.text {
////            case "==":
////                query = "\(query) = ";
////            case "<", "<=", ">=", ">":
////                query = "\(query) \(operation.operatorToken.text) ";
////            case "!=":
////                query = "\(query) <>"
////            case "&&":
////                query = "\(query) and";
////            case "||":
////                query = "\(query) or";
////            default:
////                throw EntitySetValuesError.invalidParameter(operation.operatorToken);
////            }
////        } else if let tuple = element.as(TupleExprSyntax.self) {
////            var subquery = "";
////            for tupleExprElement in tuple.elements {
////                guard let sequence = tupleExprElement.expression.as(SequenceExprSyntax.self) else {
////                    throw EntitySetValuesError.invalidParameter(tuple);
////                }
////                for subelem in sequence.elements {
////                    try convert(element: subelem, entityVariable: entityVariable, query: &subquery, params: &params);
////                }
////            }
////            query = "\(query) (\(subquery))";
////        } else {
////            query = "\(query) ?";
////            params.append(element);
////        }
////
////    }
//}
