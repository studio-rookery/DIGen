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
    let providers: [ProviderDesciptor]
    let injectables: [InjectableDescriptor]
    
    init(parsedFiles: [ParsedFile]) {
        self.parsedFiles = parsedFiles
        self.imports = parsedFiles.flatMap(\.imports)
        self.providers = parsedFiles.flatMap(\.providerDescriptors)
        self.injectables = parsedFiles.flatMap(\.injectableDescriptors)
    }
    
    func makeResolvers() throws -> [ResolverDescriptor] {
        try providers.map(makeResolver(from:))
    }
    
    func makeResolver(from provider: ProviderDesciptor) throws -> ResolverDescriptor {
        let graph = try DependencyGraph(provider: provider, injectables: injectables)
        return ResolverDescriptor(
            providerName: provider.name,
            graph: graph
        )
    }
}
