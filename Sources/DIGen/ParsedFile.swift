//
//  ParsedFile.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

struct ParsedFile {
    
    let imports: [ImportDescriptor]
    let providerDescriptors: [ProviderDesciptor]
    let injectableDescriptors: [InjectableDescriptor]
    
    init(file: File) throws {
        self.imports = try ImportDescriptor.imports(in: file)
        let structure = try Structure(file: file)
        self.providerDescriptors = structure.subStructures.compactMap(ProviderDesciptor.init)
        self.injectableDescriptors = structure.subStructures.compactMap(InjectableDescriptor.init)
    }
    
    init(contents: String) throws {
        let file = File(contents: contents)
        try self.init(file: file)
    }
}
