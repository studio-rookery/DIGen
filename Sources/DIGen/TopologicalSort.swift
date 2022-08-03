//
//  File.swift
//  
//
//  Created by masaki on 2022/07/31.
//

import Foundation

public struct Node<Element> {
    
    public var element: Element
    public let dependencies: [Element]

    public init(element: Element, dependencies: [Element]) {
        self.element = element
        self.dependencies = dependencies
    }
}

public enum TopologicalSort {

    public enum Error: Swift.Error, Hashable {
        case invalidGraph
    }
    
    static func run<Element: Equatable>(_ nodes: [Node<Element>]) -> Result<[Element], Error> {
        run(nodes, isEquivalent: ==)
    }
    
    static func run<Element>(_ nodes: [Node<Element>], isEquivalent: @escaping (Element, Element) -> Bool) -> Result<[Element], Error> {
        var resultElements: [Element] = []
        
        var dependencyGraph = DependencyGraph(nodes: nodes, isEquivalent: isEquivalent)
        
        while !dependencyGraph.isEmpty {
            guard let element = dependencyGraph.removeNonDependentElement() else {
                return .failure(.invalidGraph)
            }
            
            resultElements.append(element)
        }
        
        return .success(resultElements)
    }
}

private struct DependencyGraph<Element> {
    
    private var edges: [Edge]
    private let isEquivalent: (Element, Element) -> Bool

    init(nodes: [Node<Element>], isEquivalent: @escaping (Element, Element) -> Bool) {
        self.isEquivalent = isEquivalent
        self.edges = nodes.map(Edge.init)
        self.edges.forEach { edge in
            edge.dependencies.forEach { dependency in
                self[dependency]?.referencingDependencies.append(edge.element)
            }
        }
    }
    
    var isEmpty: Bool {
        edges.isEmpty
    }
    
    mutating func removeNonDependentElement() -> Element? {
        guard let index = edges.firstIndex(where: \.hasNonDependent) else {
            return nil
        }

        let edge = edges.remove(at: index)
        let element = edge.element
        let dependencies = edge.dependencies
        dependencies.forEach { dependency in
            let referencingDependencies = self[dependency]?.referencingDependencies
            guard let index = referencingDependencies?.firstIndex(where: { isEquivalent($0, element) }) else {
                return
            }

            self[dependency]?.referencingDependencies.remove(at: index)
        }

        return element
    }
}

private extension DependencyGraph {
    
    struct Edge: CustomStringConvertible {
        let element: Element
        let dependencies: [Element]
        var referencingDependencies: [Element]
        
        init(from node: Node<Element>) {
            self.element = node.element
            self.dependencies = node.dependencies
            self.referencingDependencies = []
        }
        
        var hasNonDependent: Bool {
            referencingDependencies.isEmpty
        }
        
        var description: String {
            "dependency to: \(dependencies) / dependent by: \(referencingDependencies)"
        }
    }
    
    subscript(_ element: Element) -> Edge? {
        get { edges.first { isEquivalent($0.element, element) } }
        set {
            guard let index = edges.firstIndex(where: { isEquivalent($0.element, element) }) else {
                return
            }

            if let newValue = newValue {
                edges[index] = newValue
            } else {
                edges.remove(at: index)
            }
        }
    }
}
