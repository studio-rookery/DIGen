//
//  InjectableDescriptorTests.swift
//  
//
//  Created by masaki on 2022/08/06.
//

import XCTest
import SourceKittenFramework
@testable import DIGen

final class InjectableDescriptorTests: XCTestCase {

    func test_parse() throws {
        let code = """
        struct A: Injectable {
            init(b: B) {
            }
        }
        """
        
        let parsedFile = try ParsedFile(contents: code)
        let result = parsedFile.injectableDescriptors[0]
        XCTAssertEqual(
            result,
            InjectableDescriptor(
                typeName: "A",
                injectFunction: .init(
                    scope: .instance,
                    name: "init",
                    arguments: [.init(label: "b", name: "b", typeName: "B")],
                    returnTypeName: nil
                )
            )
        )
    }
    
    func test_parse_noInit_orFactoryMethod() throws {
        let code = """
        struct A: Injectable {
        
        }
        """
        
        do {
            _ = try ParsedFile(contents: code)
            XCTFail()
        } catch let error as InjectableDescriptor.Error {
            XCTAssertEqual(error, .couldNotFindInitializerOrFactoryMethod(typeName: "A"))
        } catch {
            throw error
        }
    }
}
