//
//  ProviderDesciptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

struct ProviderDesciptor: Equatable {
    
    static let providerProtocolName = "Provider"
    
    let name: String
    let functions: [FunctionInterfaceDescriptor]
    let inheritedFunctions: [FunctionInterfaceDescriptor]
    let inheritedProviderNames: [String]
    
    func canMakeInterceptFunction(of typeName: String) -> Bool {
        !inheritedFunctions.compactMap(\.returnTypeName).contains(typeName)
    }
    
    var allFunctions: [FunctionInterfaceDescriptor] {
        (functions + inheritedFunctions).uniqued()
    }
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
        self.inheritedProviderNames = []
        self.inheritedFunctions = []
    }
    
    init?(from node: ProtocolTree.Node) {
        let structure = node.structure
        guard let name = structure.name else {
            return nil
        }
        self.name = name
        self.functions = structure.subStructures
            .compactMap(FunctionInterfaceDescriptor.init)
            .filter(\.isProvideFunction)
        self.inheritedFunctions = node
            .reculsiveParents
            .compactMap(ProviderDesciptor.init)
            .flatMap(\.functions)
        self.inheritedProviderNames = node.parents.map(\.typeName)
    }
}
