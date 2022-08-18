//
//  ProtocolTreeTests.swift
//  
//
//  Created by masaki on 2022/08/06.
//

import XCTest
import SourceKittenFramework
@testable import DIGen

final class ProtocolTreeTests: XCTestCase {

    func test_descendants() throws {
        let code = """
        protocol A: Provider { }
        protocol B: A { }
        protocol C: B { }
        protocol D { }
        protocol E: D, C { }
        """
        let composer = try ProtocolTree(nodes: ParsedFile(contents: code).protocolNodes)
        XCTAssertEqual(composer.descendants(of: "Provider").map(\.typeName).sorted(), ["A", "B", "C", "E"])
        XCTAssertEqual(composer.descendants(of: "A").map(\.typeName).sorted(), ["B", "C", "E"])
        XCTAssertEqual(composer.descendants(of: "B").map(\.typeName).sorted(), ["C", "E"])
        XCTAssertEqual(composer.descendants(of: "C").map(\.typeName).sorted(), ["E"])
        XCTAssertEqual(composer.descendants(of: "D").map(\.typeName).sorted(), ["E"])
        XCTAssertEqual(composer.descendants(of: "E").map(\.typeName).sorted(), [])
    }
    
    func test_circular_reference() throws {
        let code = """
        protocol A: C { }
        protocol B: A { }
        protocol C: B { }
        """
        
        do {
            _ = try ProtocolTree(nodes: ParsedFile(contents: code).protocolNodes)
            XCTFail()
        } catch let error as ProtocolTree.Error {
            XCTAssertEqual(error, .couldNotResolveInheritanceGraph("C", "B"))
        } catch {
            throw error
        }
    }
}

