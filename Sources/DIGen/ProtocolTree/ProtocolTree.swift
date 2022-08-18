//
//  ProtocolTree.swift
//  
//
//  Created by masaki on 2022/08/06.
//

import Foundation
import SourceKittenFramework

struct ProtocolTree {

    enum Error: LocalizedError, Equatable {
        case couldNotResolveInheritanceGraph(String, String)
        
        var errorDescription: String? {
            switch self {
            case .couldNotResolveInheritanceGraph(let typeA, let typeB):
                return "Could not resolve inheritance graph due to circular references in `\(typeA)` and `\(typeB)`."
            }
        }
    }
    
    final class Node {
        let typeName: String
        let structure: Structure

        private(set) var parents: [Node] = []

        init?(structure: Structure) {
            guard structure.kind == .protocol, let name = structure.name else {
                return nil
            }

            self.typeName = name
            self.structure = structure
        }
        
        var inheritedTypeNames: [String] {
            structure.inheritedTypeNames
        }

        var reculsiveParents: [Node] {
            parents.flatMap { [$0] + $0.reculsiveParents }
        }
        
        func isDescendant(of typeName: String) -> Bool {
            reculsiveParents.contains { $0.isDescendant(of: typeName) } || inheritedTypeNames.contains(typeName)
        }

        func addParent(_ node: Node) throws {
            guard !node.reculsiveParents.map(\.typeName).contains(typeName) else {
                throw Error.couldNotResolveInheritanceGraph(typeName, node.typeName)
            }
            
            parents.append(node)
        }
    }
    
    private let nodes: [Node]
    
    init(nodes: [Node]) throws {
        let keyValues = nodes.map { ($0.typeName, $0) }
        let nodesMap: [String : Node] = Dictionary(keyValues) { a, b in
            b
        }
        
        try nodesMap.sorted { $0.key < $1.key }.forEach { typeName, node in
            try node
                .inheritedTypeNames
                .compactMap { nodesMap[$0] }
                .forEach {
                    try node.addParent($0)
                }
        }
        
        self.nodes = nodes
    }
    
    func descendants(of protocolName: String) -> [Node] {
        nodes.filter { $0.isDescendant(of: protocolName) }
    }
}
