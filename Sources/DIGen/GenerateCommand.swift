//
//  FileFinder.swift
//  
//
//  Created by masaki on 2022/08/03.
//

import Foundation
import ArgumentParser
import SourceKittenFramework

extension FileManager {
    
    func recursiveURLs(in url: URL) -> [URL] {
        enumerator(at: url, includingPropertiesForKeys: nil, options: [], errorHandler: nil)?.compactMap { $0 as? URL } ?? []
    }
}

extension URL: ExpressibleByArgument {
    
    public init?(argument: String) {
        self.init(string: argument)
    }
    
    var isSwiftFile: Bool {
        pathExtension == "swift"
    }
}

struct GenerateCommand: ParsableCommand {
    
    @Argument(help: "base path for search swift files")
    var path: URL
    
    mutating func run() throws {
        let parameter = Parameter(path: path)
        let output = try run(with: parameter)
        print(output)
    }
    
    struct Parameter {
        let path: URL
    }
    
    func run(with parameter: Parameter) throws -> String {
        let swiftURLs = FileManager.default
            .recursiveURLs(in: parameter.path)
            .filter(\.isSwiftFile)
        
        let files = swiftURLs.compactMap { url in
            File(path: url.path)
        }
        
        let parsedFiles = try files.map { file in
            try ParsedFile(file: file)
        }
        
        let composer = DependencyGraphComposer(parsedFiles: parsedFiles)        
        
        let generator = CodeGenerator()
        let generated = try generator.generate(from: composer)
        
        return generated
    }
}

