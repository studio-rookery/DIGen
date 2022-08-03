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
        print(try codeGenerator.generate(from: composer))
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
        XCTAssertThrowsError(try codeGenerator.generate(from: composer))
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

struct ResolverDescriptor {
    
    let providerName: String
    let graph: DependencyGraph
    
    var name: String {
        providerName.replacingOccurrences(of: "Provider", with: "Resolver")
    }
    
    var resolveFunctionInterfaces: [FunctionInterfaceDescriptor] {
        graph.typeNames.map(graph.makeResolveFunctionInterface(for:))
    }
    
    var interceptFunctionInterfaces: [FunctionInterfaceDescriptor] {
        graph.typeNames.map(graph.makeInterceptFunctionInterface(for:))
    }
    
    var resolveFunctionImpls: [FunctionImplDescriptor] {
        graph.typeNames.map(graph.makeResolveFunctionImpl(for:))
    }
    
    var interceptFunctionImpls: [FunctionImplDescriptor] {
        graph.typeNames.map(graph.makeInterceptFunctionImpl(for:))
    }
}

struct DependencyGraphComposer {
    
    let parsedFiles: [ParsedFile]

    let providers: [ProviderDesciptor]
    let injectables: [InjectableDescriptor]
    
    init(parsedFiles: [ParsedFile]) {
        self.parsedFiles = parsedFiles
        self.providers = parsedFiles.flatMap(\.providerDescriptors)
        self.injectables = parsedFiles.flatMap(\.injectableDescriptors)
    }
    
    func makeResolvers() throws -> [ResolverDescriptor] {
        try providers.map(makeResolver(from:))
    }
    
    func makeResolver(from provider: ProviderDesciptor) throws -> ResolverDescriptor {
        let graph = try DependencyGraph(provider: provider, injectables: injectables)
        return ResolverDescriptor(
            providerName: provider.name,
            graph: graph
        )
    }
}

struct CodeGenerator {
    
    func generate(from composer: DependencyGraphComposer) throws -> String {
        let header = """
        public protocol Injectable {
        
        }
        
        public protocol Provider {
        
        }
        
        
        """
        let resolvers = try generate(from: composer.makeResolvers())
        return header + resolvers
    }
    
    func generate(from resolvers: [ResolverDescriptor]) -> String {
        resolvers
            .map(generate(from:))
            .map { $0 + .lineBreak }
            .joinedWithLineBreak()
    }
    
    func generate(from resolver: ResolverDescriptor) -> String {
        func code<T: CustomStringConvertible>(_ objects: [T], inserLineBreak: Bool = true) -> String {
            objects
                .map {
                    $0
                        .description
                        .indented()
                        .lines
                        .filter { line in
                            !line.allSatisfy { $0 == " " }
                        }
                }
                .joined(separator: inserLineBreak ? [""] : [])
                .compactMap { $0 }
                .joinedWithLineBreak()
        }
        
        let result = """
        protocol \(resolver.name): \(resolver.providerName) {
        \(code(resolver.resolveFunctionInterfaces, inserLineBreak: false))
        
        \(code(resolver.interceptFunctionInterfaces, inserLineBreak: false))
        }
        
        extension \(resolver.name) {
        
        \(code(resolver.resolveFunctionImpls))
        }
        
        extension \(resolver.name) {
        
        \(code(resolver.interceptFunctionImpls))
        }
        """
        
        return result
    }
}

@dynamicMemberLookup
struct DependencyNodeRef {
    
    let argument: ArgumentDescriptor
    let dependency: DependencyNode
    
    var isParameterInjectType: Bool {
        dependency.injectType == .parameter
    }
    
    subscript<U>(dynamicMember keyPath: KeyPath<DependencyNode, U>) -> U {
        dependency[keyPath: keyPath]
    }
}

final class DependencyNode {
    
    enum InjectType {
        case provider
        case injectable
        case parameter
    }
    
    let typeName: String
    let injectType: InjectType
    let function: FunctionInterfaceDescriptor

    private(set) var dependencies: [DependencyNodeRef] = []
    
    init?(providerFunction: FunctionInterfaceDescriptor) {
        guard let typeName = providerFunction.returnTypeName else {
            return nil
        }
        self.typeName = typeName
        self.injectType = .provider
        self.function = providerFunction
    }
    
    init(injectable: InjectableDescriptor) {
        self.typeName = injectable.typeName
        self.injectType = .injectable
        self.function = injectable.injectFunction
    }
    
    init(parameter typeName: String) {
        self.injectType = .parameter
        self.typeName = typeName
        self.function = .init(scope: .instance, name: "", arguments: [], returnTypeName: nil)
    }
    
    var arguments: [ArgumentDescriptor] {
        function.arguments
    }
    
    var reculsiveDepdenecyRefs: [DependencyNodeRef] {
        dependencies.flatMap { ref in
            [ref] + ref.reculsiveDepdenecyRefs
        }
    }
    
    func add(_ nodeRef: DependencyNodeRef) throws {
        guard !nodeRef.reculsiveDepdenecyRefs.map(\.typeName).contains(typeName), nodeRef.typeName != typeName else {
            throw DependencyError.couldNotResolveGraph(typeName, nodeRef.typeName)
        }
        
        dependencies.append(nodeRef)
    }
}

struct DependencyGraph {
    
    private let nodes: [String : DependencyNode]
    
    init(provider: ProviderDesciptor, injectables: [InjectableDescriptor]) throws {
        let allNodes = injectables.map(DependencyNode.init) + provider.functions.compactMap(DependencyNode.init)
        let keyValues = allNodes.map { ($0.typeName, $0) }
        self.nodes = Dictionary(keyValues) { a, b in b }
        try self.nodes.forEach { (key, node) in
            let dependencies = node.arguments.map { argument -> DependencyNodeRef in
                if let dependecy = nodes[argument.typeName] {
                    return DependencyNodeRef(argument: argument, dependency: dependecy)
                } else {
                    return DependencyNodeRef(argument: argument, dependency: DependencyNode(parameter: argument.typeName))
                }
            }
            
            try dependencies.forEach {
                try node.add($0)
            }
        }
    }
    
    var typeNames: [String] {
        nodes.keys.sorted()
    }
    
    func reculsiveDepdenecyRefs(of typeName: String) -> [DependencyNodeRef] {
        guard let node = nodes[typeName] else {
            return []
        }
        
        return node.dependencies.flatMap { ref in
            [ref] + reculsiveDepdenecyRefs(of: ref.dependency.typeName)
        }
    }
    
    func makeResolveFunctionInterface(for typeName: String) -> FunctionInterfaceDescriptor {
        FunctionInterfaceDescriptor(
            scope: .instance,
            name: "resolve\(typeName)",
            arguments: reculsiveDepdenecyRefs(of: typeName)
                .filter(\.isParameterInjectType)
                .map { node in
                    node.argument
                },
            returnTypeName: typeName
        )
    }
    
    func makeInterceptFunctionInterface(for typeName: String) -> FunctionInterfaceDescriptor {
        FunctionInterfaceDescriptor(
            scope: .instance,
            name: "intercept\(typeName)",
            arguments: [
                .init(label: "_", name: "build", typeName: "() -> \(typeName)")
            ],
            returnTypeName: typeName
        )
    }
    
    func makeResolveFunctionImpl(for typeName: String) -> FunctionImplDescriptor {
        let node = nodes[typeName]!
        let interface = makeResolveFunctionInterface(for: typeName)
        
        let localVariables = node
            .dependencies
            .filter { !$0.isParameterInjectType }
            .map { ref -> String in
                let interface = makeResolveFunctionInterface(for: ref.dependency.typeName)
                let args = interface.arguments.map { arg in
                    "\(arg.label): \(arg.label)"
                }
                return "let \(ref.argument.label) = \(interface.name)(\(args.joined(separator: ", ")))"
            }
            .joined(separator: "\n")
        
        let v = node.arguments.map { argument in
            "\(argument.label): \(argument.label)"
        }
        .joined(separator: ", ")
        let compose = node.injectType == .provider ? "return \(node.function.name)(\(v))" : "return .\(node.function.name)(\(v))"
        let impl = """
        return intercept\(typeName) {
        \(localVariables.indented())
        \(compose.indented())
        }
        """
        
        let resolve = FunctionImplDescriptor(
            interface: interface,
            impl: impl
                .lines
                .filter { !$0.isEmpty }
                .joinedWithLineBreak()
        )
        
        return resolve
    }
    
    func makeInterceptFunctionImpl(for typeName: String) -> FunctionImplDescriptor {
        FunctionImplDescriptor(
            interface: makeInterceptFunctionInterface(for: typeName),
            impl: "return build()"
        )
    }
}


struct ParsedFile {
    
    let providerDescriptors: [ProviderDesciptor]
    let injectableDescriptors: [InjectableDescriptor]
    
    init(structure: Structure) {
        self.providerDescriptors = structure.subStructures.compactMap(ProviderDesciptor.init)
        self.injectableDescriptors = structure.subStructures.compactMap(InjectableDescriptor.init)
    }
    
    init(contents: String) throws {
        let structure = try Structure(file: File(contents: contents))
        self.init(structure: structure)
    }
}

enum DependencyError: LocalizedError {
    case couldNotResolveGraph(String, String)
    
    var errorDescription: String? {
        switch self {
        case .couldNotResolveGraph(let typeA, let typeB):
            return "Could not resolve dependency graph due to circular references in `\(typeA)` and `\(typeB)`."
        }
    }
}
