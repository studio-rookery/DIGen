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
