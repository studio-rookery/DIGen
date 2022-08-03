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
