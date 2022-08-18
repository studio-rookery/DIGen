//
//  DependencyGraphComposer.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

struct DependencyGraphComposer {
    
    let parsedFiles: [ParsedFile]

    let imports: [ImportDescriptor]    
    let resolvers: [ResolverDescriptor]
    
    init(parsedFiles: [ParsedFile]) throws {
        self.parsedFiles = parsedFiles
        self.imports = parsedFiles.flatMap(\.imports)
        let injectables = parsedFiles.flatMap(\.injectableDescriptors)
        let protocolTree = try ProtocolTree(nodes: parsedFiles.flatMap(\.protocolNodes))
        let providers = protocolTree
            .descendants(of: ProviderDesciptor.providerProtocolName)
            .compactMap(ProviderDesciptor.init)
        
        let resolvers = try providers.map { provider in
            try ResolverDescriptor(
                provider: provider,
                graph: DependencyGraph(provider: provider, injectables: injectables)
            )
        }
        
        let resolverMap = Dictionary(grouping: resolvers, by: \.name).compactMapValues(\.first)
        resolverMap.forEach { typeName, resolver in
            resolver
                .inhertedResolverNames
                .compactMap { resolverMap[$0] }
                .forEach(resolver.addParent)
        }
        self.resolvers = resolvers
    }
}
