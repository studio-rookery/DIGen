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
        class A: Injectable {
        
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
    
    func test_parse_memberwise_initializer() throws {
        let code = """
        struct A: Injectable {
            let value: Int
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
                    arguments: [.init(label: "value", name: "value", typeName: "Int")],
                    returnTypeName: nil
                )
            )
        )
    }
}

struct A { }
struct B { }
struct C { }

protocol AProvider: Provider {
    func provide() -> A
}
protocol BProvider: AProvider {
    func provide() -> B
}
protocol CProvider: BProvider {
    func provide() -> C
}
public protocol Injectable {

}

public protocol Provider {

}

protocol AResolver: AProvider {
     func resolveA() -> A

     func interceptA(_ build: () -> A) -> A
}

extension AResolver {

     func resolveA() -> A {
          return interceptA {
               return provide()
          }
     }
}

extension AResolver {

     func interceptA(_ build: () -> A) -> A {
          return build()
     }
}

protocol BResolver: BProvider, AResolver {
     func resolveB() -> B

     func interceptB(_ build: () -> B) -> B
}

extension BResolver {

     func resolveB() -> B {
          return interceptB {
               return provide()
          }
     }
}

extension BResolver {

     func interceptB(_ build: () -> B) -> B {
          return build()
     }
}

protocol CResolver: CProvider, BResolver {
     func resolveC() -> C

     func interceptC(_ build: () -> C) -> C
}

extension CResolver {

     func resolveC() -> C {
          return interceptC {
               return provide()
          }
     }
}

extension CResolver {

     func interceptC(_ build: () -> C) -> C {
          return build()
     }
}


func test(resolver: CResolver) {
    
}
