//
//  CodeGenerator.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

struct CodeGenerator {
    
    func generate(from resolvers: [ResolverDescriptor]) -> String {
        let header = """
        public protocol Injectable {
        
        }
        
        public protocol Provider {
        
        }
        
        
        """
        let generated = resolvers
            .map(generate(from:))
            .map { $0 + .lineBreak }
            .joinedWithLineBreak()
        
        return header + generated
    }
    
    func generate(from resolver: ResolverDescriptor) -> String {
        func code<T: CustomStringConvertible>(_ objects: [T], inserLineBreak: Bool = true) -> String {
            objects
                .map {
                    $0
                        .description
                        .indented()
                        .lines
                        .filter { line in
                            !line.allSatisfy { $0 == " " }
                        }
                }
                .joined(separator: inserLineBreak ? [""] : [])
                .compactMap { $0 }
                .joinedWithLineBreak()
        }
        
        let result = """
        protocol \(resolver.name): \(resolver.providerName) {
        \(code(resolver.resolveFunctionInterfaces, inserLineBreak: false))
        
        \(code(resolver.interceptFunctionInterfaces, inserLineBreak: false))
        }
        
        extension \(resolver.name) {
        
        \(code(resolver.resolveFunctionImpls))
        }
        
        extension \(resolver.name) {
        
        \(code(resolver.interceptFunctionImpls))
        }
        """
        
        return result
    }
}
