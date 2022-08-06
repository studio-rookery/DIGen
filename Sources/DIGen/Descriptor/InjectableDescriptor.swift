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
        guard let injectFunction = function else {
            throw Error.couldNotFindInitializerOrFactoryMethod(typeName: name)
        }
        
        self.typeName = name
        self.injectFunction = injectFunction
    }
}
