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
        let di = DI(parsedFiles: [parsedFile])
        let codeGenerator = CodeGenerator()
        print(codeGenerator.generate(from: di))
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

struct DI {
    
    let parsedFiles: [ParsedFile]

    let providers: [ProviderDesciptor]
    let injectables: [InjectableDescriptor]
    
    init(parsedFiles: [ParsedFile]) {
        self.parsedFiles = parsedFiles
        self.providers = parsedFiles.flatMap(\.providerDescriptors)
        self.injectables = parsedFiles.flatMap(\.injectableDescriptors)
    }
    
    func makeResolvers() -> [ResolverDescriptor] {
        providers.map(makeResolver(from:))
    }
    
    func makeResolver(from provider: ProviderDesciptor) -> ResolverDescriptor {
        let nodes = DependencyNode.nodes(provider: provider, injectables: injectables)
        let graph = DependencyGraph(nodes: nodes)
        return ResolverDescriptor(
            providerName: provider.name,
            graph: graph
        )
    }
}

struct CodeGenerator {
    
    func generate(from di: DI) -> String {
        let header = """
        public protocol Injectable {
        
        }
        
        public protocol Provider {
        
        }
        
        
        """
        let resolvers = generate(from: di.makeResolvers())
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

extension String {
    
    func indented() -> String {
        lines
            .map {
                "     \($0)"
            }
            .joinedWithLineBreak()
    }
}

struct DependencyNodeRef: Equatable {
    
    let argument: ArgumentDescriptor
    let dependency: DependencyNode
    
    var isParameterInjectType: Bool {
        dependency.injectType == .parameter
    }
}

struct DependencyNode: Equatable {
    
    enum InjectType: Equatable {
        case provider
        case injectable
        case parameter
    }
    
    let typeName: String
    let injectType: InjectType
    let function: FunctionInterfaceDescriptor

    var dependencies: [DependencyNodeRef] = []
    
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
    
    static func nodes(provider: ProviderDesciptor, injectables: [InjectableDescriptor]) -> [String : DependencyNode] {
        let allNodes = injectables.map(DependencyNode.init) + provider.functions.compactMap(DependencyNode.init)
        var nodes: [String : DependencyNode] = Dictionary(allNodes.map { ($0.typeName, $0) }) { a, b in
            b
        }
        
        nodes.forEach { (key, node) in
            let dependencies = node.arguments.map { argument -> DependencyNodeRef in
                if let dependecy = nodes[argument.typeName] {
                    return DependencyNodeRef(argument: argument, dependency: dependecy)
                } else {
                    return DependencyNodeRef(argument: argument, dependency: DependencyNode(parameter: argument.typeName))
                }
            }
            nodes[key]?.dependencies = dependencies
        }
        
        return nodes
    }
}

struct DependencyGraph {
    
    private let nodes: [String : DependencyNode]

    init(nodes: [String : DependencyNode]) {
        self.nodes = nodes
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
    
    func resolve(_ typeName: String) -> ResolvedNode? {
        guard let node = nodes[typeName] else {
            return nil
        }
        
        return ResolvedNode(
            typeName: typeName,
            dependencyNodes: node.dependencies.compactMap { dependency in
                resolve(dependency.dependency.typeName)
            }
        )
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

struct ResolvedNode {
    
    let typeName: String
    let dependencyNodes: [ResolvedNode]
    
    var flattenDepdendencies: [ResolvedNode] {
        dependencyNodes.flatMap {
            [$0] + $0.flattenDepdendencies
        }
    }
}

struct InjectableDescriptor: Equatable {
    
    static let injectableProtocolName = "Injectable"
    
    let typeName: String
    let injectFunction: FunctionInterfaceDescriptor
}

extension InjectableDescriptor {
    
    init?(from structure: Structure) {
        guard
            [SwiftDeclarationKind.struct, .class, .enum, .extension].contains(structure.kind),
            let name = structure.name,
            structure.inheritedTypeNames.contains(Self.injectableProtocolName)
        else {
            return nil
        }
        
        let functions = structure.subStructures.compactMap(FunctionInterfaceDescriptor.init)
        let function = functions.first { $0.isInitializer || $0.isFactoryMethod(of: name) }
        guard let injectFunction = function else {
            return nil
        }
        
        self.typeName = name
        self.injectFunction = injectFunction
    }
}

struct ProviderDesciptor: Equatable {
    
    static let providerProtocolName = "Provider"
    
    let name: String
    let functions: [FunctionInterfaceDescriptor]
}

extension ProviderDesciptor {
    
    init?(from structure: Structure) {
        guard structure.kind == .protocol, let name = structure.name, structure.inheritedTypeNames.contains(Self.providerProtocolName) else {
            return nil
        }
        self.name = name
        self.functions = structure.subStructures
            .compactMap(FunctionInterfaceDescriptor.init)
            .filter(\.isProvideFunction)
    }
}

enum FunctionScope {
    case instance
    case `static`
    case `class`
    
    init?(kind: SwiftDeclarationKind?) {
        switch kind {
        case .functionMethodInstance:
            self = .instance
        case .functionMethodStatic:
            self = .static
        case .functionMethodClass:
            self = .class
        default:
            return nil
        }
    }
}

struct FunctionInterfaceDescriptor: Equatable, CustomStringConvertible {
    
    let scope: FunctionScope
    let name: String
    let arguments: [ArgumentDescriptor]
    let returnTypeName: String?
    
    var isInitializer: Bool {
        name == "init"
    }
    
    func isFactoryMethod(of type: String) -> Bool {
        returnTypeName == type || returnTypeName == "Self"
    }
    
    var description: String {
        var returnType: String {
            if let returnTypeName = returnTypeName {
                return " -> \(returnTypeName)"
            } else {
                return ""
            }
        }
        return "func \(name)(\(arguments.map(\.description).joined(separator: ", ")))\(returnType)"
    }
    
    var isProvideFunction: Bool {
        name.hasPrefix("provide")
    }
}

extension FunctionInterfaceDescriptor {
    
    init?(from structure: Structure) {
        guard
            let scope = FunctionScope(kind: structure.kind),
            let name = structure.name
        else {
            return nil
        }
        self.scope = scope
        self.name = name.prefix { $0 != "(" }.map(\.description).joined()
        let labels = name.drop { $0 != "(" }.dropFirst().dropLast().components(separatedBy: ":").filter { !$0.isEmpty }
        self.arguments = zip(labels, structure.subStructures).compactMap { label, structure in
            ArgumentDescriptor(label: label, structure: structure)
        }
        self.returnTypeName = structure.typeName
    }
}

struct ArgumentDescriptor: Equatable, CustomStringConvertible {
    
    let label: String
    let name: String?
    let typeName: String
    
    var description: String {
        if let name = name, name != label {
            return "\(label) \(name): \(typeName)"
        } else {
            return "\(label): \(typeName)"
        }
    }
}

extension ArgumentDescriptor {
    
    init?(label: String, structure: Structure) {
        guard
            structure.kind == .varParameter,
            let typeName = structure.typeName
        else {
            return nil
        }
        
        self.label = label
        self.name = structure.name
        self.typeName = typeName
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

extension Structure {
    
    subscript<T: SourceKitRepresentable>(_ key: SwiftDocKey) -> T? {
        dictionary[key.rawValue] as? T
    }
    
    func substructures(forKey key: SwiftDocKey) -> [Structure] {
        guard let dictionaries: [[String : SourceKitRepresentable]] = self[key] else {
            return []
        }
        
        return dictionaries.map(Structure.init(sourceKitResponse:))
    }
    
    var name: String? {
        self[.name]
    }
    
    var kind: SwiftDeclarationKind? {
        guard let kind: String = self[.kind] else {
            return nil
        }
        
        return SwiftDeclarationKind(rawValue: kind)
    }
    
    var subStructures: [Structure] {
        substructures(forKey: .substructure)
    }
    
    var inheritedTypeNames: [String] {
        substructures(forKey: .inheritedtypes).compactMap(\.name)
    }
    
    var typeName: String? {
        self[.typeName]
    }
    
    func isKind(anyOf kinds: [SwiftDeclarationKind]) -> Bool {
        kinds.contains { $0 == kind }
    }
}

struct FunctionImplDescriptor: Equatable {
    
    let interface: FunctionInterfaceDescriptor
    let impl: String
}

extension FunctionImplDescriptor: CustomStringConvertible {
    
    var description: String {
        """
        \(interface) {
        \(impl.components(separatedBy: "\n").map { $0.indented() }.joined(separator: "\n"))
        }
        """
    }
}

extension String {
    
    static let lineBreak = "\n"
    
    var lines: [String] {
        components(separatedBy: String.lineBreak)
    }
    
    func byModifyingLines(_ line: (String) -> String) -> String {
        lines.map(line).joinedWithLineBreak()
    }
}

extension Collection where Element == String {
    
    func joinedWithLineBreak() -> String {
        joined(separator: .lineBreak)
    }
}
