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
    
    func isInclusive(exclusiveURLs: [URL]) -> Bool {
        !exclusiveURLs.map(\.path).contains(where: path.hasPrefix)
    }
}

struct GenerateCommand: ParsableCommand {
    
    @Argument(help: "base path for search swift files")
    var path: URL
    
    @Option(name: .shortAndLong, help: "exclusive paths")
    var exclusivePaths: [String]
    
    mutating func run() throws {
        let parameter = Parameter(path: path, exclusivePaths: exclusivePaths)
        let output = try run(with: parameter)
        print(output)
    }
    
    struct Parameter {
        let path: URL
        var exclusivePaths: [String]
        var exclusiveURLs: [URL] {
            exclusivePaths.map(path.appendingPathComponent)
        }
    }
    
    func run(with parameter: Parameter) throws -> String {
        let swiftURLs = FileManager.default
            .recursiveURLs(in: parameter.path)
            .filter(\.isSwiftFile)
            .filter { $0.isInclusive(exclusiveURLs: parameter.exclusiveURLs) }
        
        let files = swiftURLs.compactMap { url in
            File(path: url.path)
        }
        
        let parsedFiles = try files.map { file in
            try ParsedFile(file: file)
        }
        
        let composer = try DependencyGraphComposer(parsedFiles: parsedFiles)        
        
        let generator = CodeGenerator()
        let generated = try generator.generate(from: composer)
        
        return generated
    }
}

