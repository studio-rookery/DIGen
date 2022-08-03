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
        let result = """
        protocol \(resolver.name): \(resolver.providerName) {
        \(generateCode(resolver.resolveFunctionInterfaces, inserLineBreak: false))
        
        \(generateCode(resolver.interceptFunctionInterfaces, inserLineBreak: false))
        }
        
        extension \(resolver.name) {
        
        \(generateCode(resolver.resolveFunctionImpls))
        }
        
        extension \(resolver.name) {
        
        \(generateCode(resolver.interceptFunctionImpls))
        }
        """
        
        return result
    }
}

private extension CodeGenerator {
    
    func generateCode<T: CustomStringConvertible>(_ objects: [T], inserLineBreak: Bool = true) -> String {
        objects
            .map { object in
                object
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
}
