//
//  File 2.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

extension Structure {
    
    subscript<T: SourceKitRepresentable>(_ key: SwiftDocKey) -> T? {
        dictionary[key.rawValue] as? T
    }
    
    func substructures(forKey key: SwiftDocKey) -> [Structure] {
        guard let dictionaries: [[String : SourceKitRepresentable]] = self[key] else {
            return []
        }
        
        return dictionaries.map(Structure.init(sourceKitResponse:))
    }
    
    var name: String? {
        self[.name]
    }
    
    var kind: SwiftDeclarationKind? {
        guard let kind: String = self[.kind] else {
            return nil
        }
        
        return SwiftDeclarationKind(rawValue: kind)
    }
    
    var subStructures: [Structure] {
        substructures(forKey: .substructure)
    }
    
    var inheritedTypeNames: [String] {
        substructures(forKey: .inheritedtypes).compactMap(\.name)
    }
    
    var typeName: String? {
        self[.typeName]
    }
    
    func isKind(anyOf kinds: [SwiftDeclarationKind]) -> Bool {
        kinds.contains { $0 == kind }
    }
}
