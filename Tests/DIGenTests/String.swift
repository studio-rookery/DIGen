//
//  File 2.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation

extension String {
    
    static let lineBreak = "\n"
    
    var lines: [String] {
        components(separatedBy: String.lineBreak)
    }
    
    func byModifyingLines(_ line: (String) -> String) -> String {
        lines.map(line).joinedWithLineBreak()
    }
    
    func indented() -> String {
        lines
            .map {
                "     \($0)"
            }
            .joinedWithLineBreak()
    }
}

extension Collection where Element == String {
    
    func joinedWithLineBreak() -> String {
        joined(separator: .lineBreak)
    }
}
