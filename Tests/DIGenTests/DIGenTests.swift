import XCTest
import SourceKittenFramework
@testable import DIGen

final class DIGenTests: XCTestCase {
    
    func test_parseImportDescriptor() throws {
        let code = """
        import UIKit
        import SwiftUI
        import UIKit
        import Foundation
        import TimeKit
        
        struct import {
            let import: import
        }
        """
        let imports = try ImportDescriptor.imports(in: File(contents: code))
        XCTAssertEqual(imports.map(\.moduleName), ["UIKit", "SwiftUI", "UIKit", "Foundation", "TimeKit"])
    }
    
    func test_parseProviderDescriptor() throws {
        let code = """
        protocol AppProvider: Provider {
            
            func provideURLSession() -> URLSession
            func provideCalendar(param1: Int, param2 param2: Int, _ param3: Int, _: Int) -> Calendar
        }
        """
        let parsedFile = try ParsedFile(contents: code)
        let providerDescriptor = try XCTUnwrap(parsedFile.providerDescriptors.first)
        let expected = ProviderDesciptor(
            name: "AppProvider",
            functions: [
                .init(
                    scope: .instance,
                    name: "provideURLSession",
                    arguments: [],
                    returnTypeName: "URLSession"
                ),
                .init(
                    scope: .instance,
                    name: "provideCalendar",
                    arguments: [
                        .init(label: "param1", name: "param1", typeName: "Int"),
                        .init(label: "param2", name: "param2", typeName: "Int"),
                        .init(label: "_", name: "param3", typeName: "Int"),
                        .init(label: "_", name: nil, typeName: "Int"),
                    ],
                    returnTypeName: "Calendar"
                ),
            ],
            inheritedFunctions: [],
            inheritedProviderNames: []
        )
        XCTAssertEqual(providerDescriptor, expected)
    }
    
    func test_parseInjectable() throws {
        let code = """
        struct Model: Injectable {
            
            init(urlSession: URLSession) {
            
            }
        }
                
        struct Model: Injectable {
            
            static func makeInstance(urlSession: URLSession) -> Model {
                Model()
            }
        }
                        
        struct Model: Injectable {
            
            static func makeInstance(urlSession: URLSession) -> Self {
                Model()
            }
        }
        
        extension Model: Injectable {
            
            init(urlSession: URLSession) {
                
            }
        }
        """
        let parsedFile = try ParsedFile(contents: code)
        XCTAssertEqual(
            parsedFile.injectableDescriptors,
            [
                .init(typeName: "Model", injectFunction: .init(scope: .instance, name: "init", arguments: [.init(label: "urlSession", name: "urlSession", typeName: "URLSession")], returnTypeName: nil)),
                .init(typeName: "Model", injectFunction: .init(scope: .static, name: "makeInstance", arguments: [.init(label: "urlSession", name: "urlSession", typeName: "URLSession")], returnTypeName: "Model")),
                .init(typeName: "Model", injectFunction: .init(scope: .static, name: "makeInstance", arguments: [.init(label: "urlSession", name: "urlSession", typeName: "URLSession")], returnTypeName: "Self")),
                .init(typeName: "Model", injectFunction: .init(scope: .instance, name: "init", arguments: [.init(label: "urlSession", name: "urlSession", typeName: "URLSession")], returnTypeName: nil))
            ]
        )
    }
    
    func test_DI() throws {
        let parsedFile = try ParsedFile(contents: vcode)
        let composer = try DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        print(codeGenerator.generate(from: composer.resolvers))
    }
    
    func test_circular_reference() throws {
        let code = """
        protocol AppProvider: Provider {  }
        
        struct A: Injectable {
            
            init(b: B) {
            
            }
        }
        struct B: Injectable {
            
            init(c: C) {
            
            }
        }
        struct C: Injectable {
            
            init(a: A) {
            
            }
        }
        """
        
        let parsedFile = try ParsedFile(contents: code)
        XCTAssertThrowsError(try DependencyGraphComposer(parsedFiles: [parsedFile]))
    }
    
    func test_same_param() throws {
        let code = """
        protocol AppProvider: Provider { }
        
        struct A: Injectable {
            
            init(b: B, c: C) {
                
            }
        }

        struct B: Injectable {
            
            init(c: C) {
                
            }
        }

        struct C {
            
            init() {
                
            }
        }
        """
        
        let parsedFile = try ParsedFile(contents: code)
        let composer = try DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        let result = codeGenerator.generate(from: composer.resolvers)
        print(result)
    }
    
    func test_inheritedProvider() throws {
        let code = """
        protocol AProvider: Provider {
            func provide() -> A
        }
        protocol BProvider: AProvider {
            func provide() -> B
        }
        protocol CProvider: BProvider {
            func provide() -> C
        }
        """
        
        let parsedFile = try ParsedFile(contents: code)
        let composer = try DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        let result = codeGenerator.generate(from: composer.resolvers)
        print(result)
    }
    
    func test_inheritedProvider2() throws {
        let code = """
        struct ViewModel: Injectable {
            init(userID: UserID) { }
        }
        
        protocol AProvider: Provider {
        
        }
        protocol BProvider: AProvider {
            func provideUserID() -> UserID
        }
        """
        
        let parsedFile = try ParsedFile(contents: code)
        let composer = try DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        let result = codeGenerator.generate(from: composer.resolvers)
        print(result)
    }
}

let vcode = """
protocol AppProvider: Provider {
    
    func provideURLSession() -> URLSession
    func provideAPIClient() -> APIClient
    func provideRepository() -> Repository
}

protocol NewProvider: AppProvider {
    
    func provideUserID() -> String
}

protocol APIClient {
    
}

struct URLSessionAPIClient: APIClient, Injectable {
    
    let urlSession: URLSession

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }
}

protocol Repository {

}

struct DefaultRepository: Repository, Injectable {

    init() {
        
    }
}

struct ViewModel: Injectable {
    
    let userID: String
    let apiClient: APIClient

    init(userID: String, apiClient: APIClient, repository: Repository) {
        self.userID = userID
        self.apiClient = apiClient
    }
}

final class ViewController: UIViewController, Injectable {

    static func fromStoryboard(viewModel: ViewModel) -> Self {
        
    }
}
"""
