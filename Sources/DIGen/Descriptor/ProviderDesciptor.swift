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
