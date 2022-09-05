//
//  InjectableDescriptor.swift
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
    
    enum Error: LocalizedError, Equatable {
        case couldNotFindInitializerOrFactoryMethod(typeName: String)
        
        var errorDescription: String? {
            switch self {
            case .couldNotFindInitializerOrFactoryMethod(let typeName):
                return "Could not find an initializer or factoryMethod in `\(typeName)`. `Injectable` must have an initializer or factoryMethod."
            }
        }
    }
    
    init?(from structure: Structure) throws {
        guard
            [SwiftDeclarationKind.struct, .class, .enum, .extension].contains(structure.kind),
            let name = structure.name,
            structure.inheritedTypeNames.contains(Self.injectableProtocolName)
        else {
            return nil
        }
        
        let functions = structure.subStructures.compactMap(FunctionInterfaceDescriptor.init)
        let function = functions.first { $0.isInitializer || $0.isFactoryMethod(of: name) }
        guard let injectFunction = function ?? .memberwiseInitializer(from: structure) else {
            throw Error.couldNotFindInitializerOrFactoryMethod(typeName: name)
        }
        
        self.typeName = name
        self.injectFunction = injectFunction
    }
}

extension FunctionInterfaceDescriptor {
    
    static func memberwiseInitializer(from structure: Structure) -> FunctionInterfaceDescriptor? {
        guard structure.isKind(anyOf: [.struct]) else {
            return nil
        }
        
        let properties = structure.subStructures.compactMap(StoredPropertyDescriptor.init)
        let hasMemberwiseInitializer = properties.allSatisfy(\.isInternal)
        
        guard hasMemberwiseInitializer else {
            return nil
        }
        
        return .init(
            scope: .instance,
            name: "init",
            arguments: properties.map { property in
                ArgumentDescriptor(label: property.name, name: property.name, typeName: property.typeName)
            },
            returnTypeName: nil
        )
    }
}

struct StoredPropertyDescriptor {
    
    let accessibility: String
    let name: String
    let typeName: String
    
    init?(structure: Structure) {
        guard
            structure.isKind(anyOf: [.varInstance]),
            let name = structure.name,
            let typeName = structure.typeName,
            let accessibility = structure.dictionary["key.accessibility"] as? String
        else {
            return nil
        }
        
        self.name = name
        self.typeName = typeName
        self.accessibility = accessibility
    }
    
    var isInternal: Bool {
        accessibility == "source.lang.swift.accessibility.internal"
    }
}
