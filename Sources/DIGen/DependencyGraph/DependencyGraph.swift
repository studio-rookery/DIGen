//
//  DependencyGraph.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

@dynamicMemberLookup
struct DependencyNodeRef {
    
    let argument: ArgumentDescriptor
    let dependency: DependencyNode
    
    var isParameterInjectType: Bool {
        dependency.injectType == .parameter
    }
    
    subscript<U>(dynamicMember keyPath: KeyPath<DependencyNode, U>) -> U {
        dependency[keyPath: keyPath]
    }
}

final class DependencyNode {
    
    enum Error: LocalizedError {
        case couldNotResolveGraph(String, String)
        
        var errorDescription: String? {
            switch self {
            case .couldNotResolveGraph(let typeA, let typeB):
                return "Could not resolve dependency graph due to circular references in `\(typeA)` and `\(typeB)`."
            }
        }
    }
    
    enum InjectType {
        case provider
        case injectable
        case parameter
    }
    
    let typeName: String
    let injectType: InjectType
    
    private let function: FunctionInterfaceDescriptor?
    private(set) var dependencies: [DependencyNodeRef] = []
    
    init?(providerFunction: FunctionInterfaceDescriptor) {
        guard let typeName = providerFunction.returnTypeName else {
            return nil
        }
        self.typeName = typeName
        self.injectType = .provider
        self.function = providerFunction
    }
    
    init(injectable: InjectableDescriptor) {
        self.typeName = injectable.typeName
        self.injectType = .injectable
        self.function = injectable.injectFunction
    }
    
    init(parameter typeName: String) {
        self.injectType = .parameter
        self.typeName = typeName
        self.function = .init(scope: .instance, name: "", arguments: [], returnTypeName: nil)
    }
    
    var functionName: String {
        function?.name ?? ""
    }
    
    var arguments: [ArgumentDescriptor] {
        function?.arguments ?? []
    }
    
    var reculsiveDepdenecyRefs: [DependencyNodeRef] {
        dependencies.flatMap { ref in
            [ref] + ref.reculsiveDepdenecyRefs
        }
    }
    
    func add(_ nodeRef: DependencyNodeRef) throws {
        guard !nodeRef.reculsiveDepdenecyRefs.map(\.typeName).contains(typeName), nodeRef.typeName != typeName else {
            throw Error.couldNotResolveGraph(typeName, nodeRef.typeName)
        }
        
        dependencies.append(nodeRef)
    }
}

struct DependencyGraph {
    
    private let nodes: [String : DependencyNode]
    
    init(provider: ProviderDesciptor, injectables: [InjectableDescriptor]) throws {
        let allNodes = injectables.map(DependencyNode.init) + provider.functions.compactMap(DependencyNode.init)
        let keyValues = allNodes.map { ($0.typeName, $0) }
        self.nodes = Dictionary(keyValues) { a, b in b }
        try self.nodes.forEach { (key, node) in
            let dependencies = node.arguments.map { argument -> DependencyNodeRef in
                if let dependecy = nodes[argument.typeName] {
                    return DependencyNodeRef(argument: argument, dependency: dependecy)
                } else {
                    return DependencyNodeRef(argument: argument, dependency: DependencyNode(parameter: argument.typeName))
                }
            }
            
            try dependencies.forEach {
                try node.add($0)
            }
        }
    }
    
    var typeNames: [String] {
        nodes.keys.sorted()
    }
    
    func reculsiveDepdenecyRefs(of typeName: String) -> [DependencyNodeRef] {
        guard let node = nodes[typeName] else {
            return []
        }
        
        return node.dependencies.flatMap { ref in
            [ref] + reculsiveDepdenecyRefs(of: ref.dependency.typeName)
        }
    }
    
    func makeResolveFunctionInterface(for typeName: String) -> FunctionInterfaceDescriptor {
        FunctionInterfaceDescriptor(
            scope: .instance,
            name: "resolve\(typeName)",
            arguments: reculsiveDepdenecyRefs(of: typeName)
                .filter(\.isParameterInjectType)
                .map { node in
                    node.argument
                },
            returnTypeName: typeName
        )
    }
    
    func makeInterceptFunctionInterface(for typeName: String) -> FunctionInterfaceDescriptor {
        FunctionInterfaceDescriptor(
            scope: .instance,
            name: "intercept\(typeName)",
            arguments: [
                .init(label: "_", name: "build", typeName: "() -> \(typeName)")
            ],
            returnTypeName: typeName
        )
    }
    
    func makeResolveFunctionImpl(for typeName: String) -> FunctionImplDescriptor {
        let node = nodes[typeName]!
        let interface = makeResolveFunctionInterface(for: typeName)
        
        let localVariables = node
            .dependencies
            .filter { !$0.isParameterInjectType }
            .map { ref -> String in
                let interface = makeResolveFunctionInterface(for: ref.dependency.typeName)
                let args = interface.arguments.map { arg in
                    "\(arg.label): \(arg.label)"
                }
                return "let \(ref.argument.label) = \(interface.name)(\(args.joined(separator: ", ")))"
            }
            .joined(separator: "\n")
        
        let v = node.arguments.map { argument in
            "\(argument.label): \(argument.label)"
        }
        .joined(separator: ", ")
        let compose = node.injectType == .provider ? "return \(node.functionName)(\(v))" : "return .\(node.functionName)(\(v))"
        let impl = """
        return intercept\(typeName) {
        \(localVariables.indented())
        \(compose.indented())
        }
        """
        
        let resolve = FunctionImplDescriptor(
            interface: interface,
            impl: impl
                .lines
                .filter { !$0.isEmpty }
                .joinedWithLineBreak()
        )
        
        return resolve
    }
    
    func makeInterceptFunctionImpl(for typeName: String) -> FunctionImplDescriptor {
        FunctionImplDescriptor(
            interface: makeInterceptFunctionInterface(for: typeName),
            impl: "return build()"
        )
    }
}

