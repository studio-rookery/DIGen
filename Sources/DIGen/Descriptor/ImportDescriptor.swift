//
//  ImportDescriptor.swift
//  
//
//  Created by masaki on 2022/08/04.
//

import Foundation
import SourceKittenFramework

struct ImportDescriptor: Equatable {
    
    let moduleName: String
    
    static func imports(in file: File) throws -> [ImportDescriptor] {
        
        func text(at token: SyntaxToken) -> String? {
            let utf8 = file.contents.utf8
            let startIndex = utf8.index(utf8.startIndex, offsetBy: token.offset.value)
            let endIndex = utf8.index(startIndex, offsetBy: token.length.value)
            return String(utf8[startIndex ..< endIndex])
        }
        
        let syntaxMap = try SyntaxMap(file: file)
        let tokens = syntaxMap.tokens
        let moduleNames = tokens
            .enumerated()
            .compactMap { index, token -> String? in
                guard token.type == SyntaxKind.keyword.rawValue, text(at: token) == "import" else {
                    return nil
                }
                
                let moduleNameIndex = index + 1
                guard tokens.indices.contains(moduleNameIndex) else {
                    return nil
                }
                
                let moduleNameToken = tokens[moduleNameIndex]
                guard moduleNameToken.type == SyntaxKind.identifier.rawValue else {
                    return nil
                }
                
                return text(at: moduleNameToken)
            }
        
        return moduleNames.map(ImportDescriptor.init)
    }
}

extension ImportDescriptor: Comparable {
    
    static func < (lhs: ImportDescriptor, rhs: ImportDescriptor) -> Bool {
        lhs.moduleName < rhs.moduleName
    }
}
