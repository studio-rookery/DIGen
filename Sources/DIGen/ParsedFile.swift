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
    let protocolNodes: [ProtocolTree.Node]
    let providerDescriptors: [ProviderDesciptor]
    let injectableDescriptors: [InjectableDescriptor]
    
    init(file: File) throws {
        let structure = try Structure(file: file)
        self.providerDescriptors = structure.subStructures.compactMap(ProviderDesciptor.init)
        self.protocolNodes = structure.subStructures.compactMap(ProtocolTree.Node.init)
        self.injectableDescriptors = try structure.subStructures.compactMap(InjectableDescriptor.init)
        let isRequiredImports = !providerDescriptors.isEmpty || !injectableDescriptors.isEmpty
        self.imports = isRequiredImports ? try ImportDescriptor.imports(in: file) : []
    }
    
    init(contents: String) throws {
        let file = File(contents: contents)
        try self.init(file: file)
    }
}
