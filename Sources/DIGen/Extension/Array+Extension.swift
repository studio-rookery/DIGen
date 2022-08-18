//
//  Array+Extension.swift
//  
//
//  Created by masaki on 2022/08/04.
//

import Foundation

extension Array {
    
    func uniqued() -> [Element] where Element: Equatable {
        var result: [Element] = []
        
        forEach {
            guard !result.contains($0) else {
                return
            }
            result.append($0)
        }
        
        return result
    }
    
    func filterUnique() -> [Element] where Element: Hashable {
        let counts = Dictionary(grouping: self) { $0 }.mapValues(\.count)
        return filter { counts[$0] == 1 }
    }
}
