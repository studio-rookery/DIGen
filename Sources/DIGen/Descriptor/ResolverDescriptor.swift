//
//  ResolverDescriptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

struct ResolverDescriptor {
    
    let providerName: String
    let graph: DependencyGraph
    
    var name: String {
        providerName.replacingOccurrences(of: "Provider", with: "Resolver")
    }
    
    var resolveFunctionInterfaces: [FunctionInterfaceDescriptor] {
        graph.typeNames.map(graph.makeResolveFunctionInterface(for:))
    }
    
    var interceptFunctionInterfaces: [FunctionInterfaceDescriptor] {
        graph.typeNames.map(graph.makeInterceptFunctionInterface(for:))
    }
    
    var resolveFunctionImpls: [FunctionImplDescriptor] {
        graph.typeNames.map(graph.makeResolveFunctionImpl(for:))
    }
    
    var interceptFunctionImpls: [FunctionImplDescriptor] {
        graph.typeNames.map(graph.makeInterceptFunctionImpl(for:))
    }
}
