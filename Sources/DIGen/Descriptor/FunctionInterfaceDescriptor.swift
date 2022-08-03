//
//  FunctionInterfaceDescriptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

enum FunctionScope {
    case instance
    case `static`
    case `class`
    
    init?(kind: SwiftDeclarationKind?) {
        switch kind {
        case .functionMethodInstance:
            self = .instance
        case .functionMethodStatic:
            self = .static
        case .functionMethodClass:
            self = .class
        default:
            return nil
        }
    }
}

struct FunctionInterfaceDescriptor: Equatable, CustomStringConvertible {
    
    let scope: FunctionScope
    let name: String
    let arguments: [ArgumentDescriptor]
    let returnTypeName: String?
    
    var isInitializer: Bool {
        name == "init"
    }
    
    func isFactoryMethod(of type: String) -> Bool {
        returnTypeName == type || returnTypeName == "Self"
    }
    
    var description: String {
        var returnType: String {
            if let returnTypeName = returnTypeName {
                return " -> \(returnTypeName)"
            } else {
                return ""
            }
        }
        return "func \(name)(\(arguments.map(\.description).joined(separator: ", ")))\(returnType)"
    }
    
    var isProvideFunction: Bool {
        name.hasPrefix("provide")
    }
}

extension FunctionInterfaceDescriptor {
    
    init?(from structure: Structure) {
        guard
            let scope = FunctionScope(kind: structure.kind),
            let name = structure.name
        else {
            return nil
        }
        self.scope = scope
        self.name = name.prefix { $0 != "(" }.map(\.description).joined()
        let labels = name.drop { $0 != "(" }.dropFirst().dropLast().components(separatedBy: ":").filter { !$0.isEmpty }
        self.arguments = zip(labels, structure.subStructures).compactMap { label, structure in
            ArgumentDescriptor(label: label, structure: structure)
        }
        self.returnTypeName = structure.typeName
    }
}
