import XCTest
import SourceKittenFramework
@testable import DIGen

final class DIGenTests: XCTestCase {
    func test_parseProviderDescriptor() throws {
        let code = """
        protocol AppProvider: Provider {
            
            func provideURLSession() -> URLSession
            func provideCalendar(param1: Int, param2 param2: Int, _ param3: Int, _: Int) -> Calendar
        }
        """
        let file = File(contents: code)
        let parsedFile = ParsedFile(structure: try Structure(file: file))
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
            ]
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
        let file = File(contents: code)
        let parsedFile = ParsedFile(structure: try Structure(file: file))
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
        let composer = DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        print(try codeGenerator.generate(from: composer.makeResolvers()))
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
        let composer = DependencyGraphComposer(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        XCTAssertThrowsError(try codeGenerator.generate(from: composer.makeResolvers()))
    }
}

let vcode = """
protocol AppProvider: Provider {
    
    func provideURLSession() -> URLSession
    func provideAPIClient() -> APIClient
    func provideRepository() -> Repository
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
