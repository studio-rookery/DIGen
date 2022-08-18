//
//  ResolverDescriptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

final class ResolverDescriptor {
    
    static func resolverName(fromProviderName name: String) -> String {
        name.replacingOccurrences(of: "Provider", with: "Resolver")
    }
    
    let provider: ProviderDesciptor
    let graph: DependencyGraph

    private var parents: [ResolverDescriptor] = []
    
    init(provider: ProviderDesciptor, graph: DependencyGraph) {
        self.provider = provider
        self.graph = graph
    }
    
    var providerName: String {
        provider.name
    }
    
    var name: String {
        ResolverDescriptor.resolverName(fromProviderName: providerName)
    }
    
    var inhertedResolverNames: [String] {
        provider.inheritedProviderNames.map(ResolverDescriptor.resolverName(fromProviderName:))
    }
    
    var resolveFunctionInterfaces: [FunctionInterfaceDescriptor] {
        graph.typeNames
            .map(graph.makeResolveFunctionInterface(for:))
            .removingElements(in: reculsiveParents.flatMap(\.resolveFunctionInterfaces).uniqued())
    }
    
    var interceptFunctionInterfaces: [FunctionInterfaceDescriptor] {
        interceptableTypeNames.map(graph.makeInterceptFunctionInterface(for:))
    }
    
    var resolveFunctionImpls: [FunctionImplDescriptor] {
        graph.typeNames
            .map(graph.makeResolveFunctionImpl(for:))
            .removingElements(in: reculsiveParents.flatMap(\.resolveFunctionImpls).uniqued())
    }
    
    var interceptFunctionImpls: [FunctionImplDescriptor] {
        interceptableTypeNames.map(graph.makeInterceptFunctionImpl(for:))
    }
    
    func addParent(_ parent: ResolverDescriptor) {
        parents.append(parent)
    }
}

private extension ResolverDescriptor {
    
    var reculsiveParents: [ResolverDescriptor] {
        parents.flatMap { [$0] + $0.reculsiveParents }
    }
    
    var interceptableTypeNames: [String] {
        let reculsiveParents = Set(reculsiveParents.flatMap(\.interceptableTypeNames))
        return graph.typeNames.filter { typeName in
            !reculsiveParents.contains(typeName)
        }
    }
}

extension Array {
    
    func removingElements(in elements: [Element]) -> [Element] where Element: Equatable {
        filter { !elements.contains($0) }
    }
}
