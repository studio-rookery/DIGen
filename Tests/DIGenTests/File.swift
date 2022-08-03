//
//  File.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

struct InjectableDescriptor: Equatable {
    
    static let injectableProtocolName = "Injectable"
    
    let typeName: String
    let injectFunction: FunctionInterfaceDescriptor
}

extension InjectableDescriptor {
    
    init?(from structure: Structure) {
        guard
            [SwiftDeclarationKind.struct, .class, .enum, .extension].contains(structure.kind),
            let name = structure.name,
            structure.inheritedTypeNames.contains(Self.injectableProtocolName)
        else {
            return nil
        }
        
        let functions = structure.subStructures.compactMap(FunctionInterfaceDescriptor.init)
        let function = functions.first { $0.isInitializer || $0.isFactoryMethod(of: name) }
        guard let injectFunction = function else {
            return nil
        }
        
        self.typeName = name
        self.injectFunction = injectFunction
    }
}

struct ProviderDesciptor: Equatable {
    
    static let providerProtocolName = "Provider"
    
    let name: String
    let functions: [FunctionInterfaceDescriptor]
}

extension ProviderDesciptor {
    
    init?(from structure: Structure) {
        guard structure.kind == .protocol, let name = structure.name, structure.inheritedTypeNames.contains(Self.providerProtocolName) else {
            return nil
        }
        self.name = name
        self.functions = structure.subStructures
            .compactMap(FunctionInterfaceDescriptor.init)
            .filter(\.isProvideFunction)
    }
}

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

struct ArgumentDescriptor: Equatable, CustomStringConvertible {
    
    let label: String
    let name: String?
    let typeName: String
    
    var description: String {
        if let name = name, name != label {
            return "\(label) \(name): \(typeName)"
        } else {
            return "\(label): \(typeName)"
        }
    }
}

extension ArgumentDescriptor {
    
    init?(label: String, structure: Structure) {
        guard
            structure.kind == .varParameter,
            let typeName = structure.typeName
        else {
            return nil
        }
        
        self.label = label
        self.name = structure.name
        self.typeName = typeName
    }
}
struct FunctionImplDescriptor: Equatable {
    
    let interface: FunctionInterfaceDescriptor
    let impl: String
}

extension FunctionImplDescriptor: CustomStringConvertible {
    
    var description: String {
        """
        \(interface) {
        \(impl.components(separatedBy: "\n").map { $0.indented() }.joined(separator: "\n"))
        }
        """
    }
}
