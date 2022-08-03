//
//  FunctionImplDescriptor.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

struct FunctionImplDescriptor: Equatable {
    
    let interface: FunctionInterfaceDescriptor
    let impl: String
}

extension FunctionImplDescriptor: CustomStringConvertible {
    
    var description: String {
        """
        \(interface) {
        \(impl.components(separatedBy: "\n").map { $0.indented() }.joined(separator: "\n"))
        }
        """
    }
}
