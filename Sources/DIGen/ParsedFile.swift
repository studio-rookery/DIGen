//
//  ParsedFile.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

struct ParsedFile {
    
    let providerDescriptors: [ProviderDesciptor]
    let injectableDescriptors: [InjectableDescriptor]
    
    init(structure: Structure) {
        self.providerDescriptors = structure.subStructures.compactMap(ProviderDesciptor.init)
        self.injectableDescriptors = structure.subStructures.compactMap(InjectableDescriptor.init)
    }
    
    init(contents: String) throws {
        let structure = try Structure(file: File(contents: contents))
        self.init(structure: structure)
    }
}
