//
//  ArgumentDescriptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

struct ArgumentDescriptor: Equatable, CustomStringConvertible {
    
    let label: String
    let name: String?
    let typeName: String
    
    var description: String {
        if let name = name, name != label {
            return "\(label) \(name): \(typeName)"
        } else {
            return "\(label): \(typeName)"
        }
    }
}

extension ArgumentDescriptor {
    
    init?(label: String, structure: Structure) {
        guard
            structure.kind == .varParameter,
            let typeName = structure.typeName
        else {
            return nil
        }
        
        self.label = label
        self.name = structure.name
        self.typeName = typeName
    }
}
