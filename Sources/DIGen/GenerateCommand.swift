//
//  FileFinder.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import SourceKittenFramework

extension FileManager {
    
    func recursiveURLs(in url: URL) -> [URL] {
        enumerator(at: url, includingPropertiesForKeys: nil, options: [], errorHandler: nil)?.compactMap { $0 as? URL } ?? []
    }
}

extension URL {
    
    var isSwiftFile: Bool {
        pathExtension == "swift"
    }
}

struct GenerateCommand {
    
    struct Parameter {
        let url: URL
    }
    
    func run(with parameter: Parameter) throws -> String {
        let swiftURLs = FileManager.default
            .recursiveURLs(in: parameter.url)
            .filter(\.isSwiftFile)
        
        let files = swiftURLs.compactMap { url in
            File(path: url.path)
        }
        
        let parsedFiles = try files.map { file in
            ParsedFile(structure: try Structure(file: file))
        }
        
        let composer = DependencyGraphComposer(parsedFiles: parsedFiles)
        let resolvers = try composer.makeResolvers()
        
        let generator = CodeGenerator()
        let generated = generator.generate(from: resolvers)
        
        return generated
    }
}

