//
//  NetworkingSession.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

public typealias BaseResponseWrapped<T: Decodable> = Result<NetworkingSession.BaseResponse<T>, NetworkingSession.RequestError>

// MARK: - NetworkingSession
open class NetworkingSession: NetworkingSessionProtocol {
    // MARK: - BaseResponse
    public struct BaseResponse<T: Decodable>: Decodable {
        public let success: Bool
        public let data: T
        public let message: String
    }

    // MARK: - Public Properties
    public private(set) var sessionManager: Session

    public private(set) var decoder: JSONDecoder = JSONDecoder()
    public private(set) var encoder: JSONEncoder = JSONEncoder()

    public var authCredential: OAuthAuthenticator.OAuthCredential? {
        didSet {
            guard
                let authCredential = authCredential
            else {
                authInterceptor = nil
                return
            }

            authInterceptor = .init(authenticator: authenticator, credential: authCredential)
        }
    }

    public weak var authDelegate: OAuthAuthenticatorDelegate? {
        didSet {
            authenticator.delegate = authDelegate
        }
    }

    public weak var interceptorDelegate: InterceptorDelegate? {
        didSet {
            requestInterceptor.delegate = interceptorDelegate
        }
    }

    public var onUnauthorizedInterceptor: (() -> Void)?

    // MARK: - Private Properties
    private var baseURL: URL?

    private let connectivity: Connectivity

    private let rootQueue: DispatchQueue
    private let requestQueue: DispatchQueue
    private let serializationQueue: DispatchQueue
    private let configuration: URLSessionConfiguration

    private let authenticator: OAuthAuthenticator = .init()
    private var authInterceptor: AuthenticationInterceptor<OAuthAuthenticator>?
    private let eventMonitor: BaseEventMonitor = .init()
    private let requestInterceptor: BaseRequestInterceptor = .init()

    // MARK: - Init
    public init(baseURL: String, connectivity: Connectivity) {
        self.baseURL = URL(string: baseURL)

        self.connectivity = connectivity

        self.rootQueue = DispatchQueue(label: "\(baseURL).\(Bundle.main.bundleIdentifier ?? "").rootQueue")
        self.requestQueue = DispatchQueue(label: "\(baseURL).\(Bundle.main.bundleIdentifier ?? "").requestQueue")
        self.serializationQueue = DispatchQueue(label: "\(baseURL).\(Bundle.main.bundleIdentifier ?? "").serializationQueue")

        self.configuration = URLSessionConfiguration.af.default
        self.configuration.timeoutIntervalForRequest = 30
        self.configuration.waitsForConnectivity = false
        self.configuration.requestCachePolicy = .reloadRevalidatingCacheData

        self.sessionManager = .init(
            configuration: configuration,
            rootQueue: rootQueue,
            startRequestsImmediately: true,
            requestQueue: requestQueue,
            serializationQueue: serializationQueue,
            interceptor: requestInterceptor,
            cachedResponseHandler: ResponseCacher(behavior: .cache),
            eventMonitors: [ eventMonitor ]
        )

        self.commonSetup()
    }

    // MARK: - Private Methods
    private func commonSetup() {
        configurateDecoder()
        configurateSnakeCaseEncoder()
        connectivity.startObserving()
    }

    private func configurateDecoder() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    private func configurateSnakeCaseEncoder() {
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .prettyPrinted
    }

    private func configurateDefaultEncoder() {
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .prettyPrinted
    }

    // MARK: - Public Methods
    // MARK: - Make Request Methods
    public func makeRequest<Model: Decodable>(_ router: AnyNetworkRouter) async throws -> Model {
        let request = try tryRequest(router)
        let response = await request.asyncResponseData()
        let result: BaseResponseWrapped<Model> = handleResponse(response)

        switch result {
            case .success(let data):
                return data.data
            case .failure(let error):
                throw error
        }
    }

    public func makeMultipartRequest<Model: Decodable>(
        _ request: AnyNetworkRouter,
        appendWith dictionary: [String: Any]
    ) async throws -> Model {
        let request = try tryMultipartRequest(request) { [weak self] multipartFormData in
            self?.appendMultipartData(multipartFormData, with: dictionary)
        }
        let response = await request.asyncResponseData()
        let result: BaseResponseWrapped<Model> = handleResponse(response)

        switch result {
            case .success(let data):
                return data.data
            case .failure(let error):
                throw error
        }
    }

    public func makeMultipartRequest<Model: Decodable>(
        _ request: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) async throws -> Model {
        let request = try tryMultipartRequest(request, appendMultipartData: appendMultipartData)
        let response = await request.asyncResponseData()
        let result: BaseResponseWrapped<Model> = handleResponse(response)

        switch result {
            case .success(let data):
                return data.data
            case .failure(let error):
                throw error
        }
    }

    // MARK: - Try Request Methods
    public func tryRequest(_ type: AnyNetworkRouter) throws -> DataRequest {
        guard case .reachable = connectivity.isReachableValue else {
            debugPrint("🆘 Request ended with error. \(RequestError.connectionLost): \(RequestError.connectionLost.errorDescription ?? "")")
            throw RequestError.connectionLost
        }

        guard
            let request = request(type)
        else {
            throw URLError(.badURL)
        }

        return request
    }

    public func tryMultipartRequest(
        _ type: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) throws -> UploadRequest {
        guard case .reachable = connectivity.isReachableValue else {
            debugPrint("🆘 Request ended with error. \(RequestError.connectionLost): \(RequestError.connectionLost.errorDescription ?? "")")
            throw RequestError.connectionLost
        }

        guard
            let request = multipartRequest(type, appendMultipartData: appendMultipartData)
        else {
            throw URLError(.badURL)
        }

        return request
    }

    // MARK: - Base Request Methods
    public func request(_ type: AnyNetworkRouter) -> DataRequest? {
        guard let baseURL = baseURL else { return nil }

        if type.method == .post || !type.withSnakeStyleEncoder {
            configurateDefaultEncoder()
        } else {
            configurateSnakeCaseEncoder()
        }

        let parameters: Parameters? = type.parameters?.asDictionary(encoder: self.encoder)

        return sessionManager.request(
            baseURL.appendingPathComponent(type.path),
            method: type.method,
            parameters: parameters,
            encoding: type.encoder,
            headers: type.headers,
            interceptor: type.addAuth ? authInterceptor : nil
        )
    }

    public func multipartRequest(
        _ type: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) -> UploadRequest? {
        guard let baseURL = baseURL else { return nil }

        return sessionManager.upload(
            multipartFormData: { multipartFormData in
                appendMultipartData(multipartFormData)
            },
            to: baseURL.appendingPathComponent(type.path),
            method: type.method,
            headers: type.headers,
            interceptor: type.addAuth ? authInterceptor : nil
        )
    }

    public func uploadFile(_ type: AnyUploadNetworkRouter) -> DataRequest? {
        guard
            let baseURL = baseURL,
            let inputStream = InputStream(url: type.fileURL)
        else {
            return nil
        }

        return sessionManager.upload(
            multipartFormData: {
                $0.append(
                    inputStream,
                    withLength: UInt64(type.fileURL.fileSize),
                    name: type.fileName,
                    fileName: "\(type.fileName)\(type.fileType)",
                    mimeType: type.mimeType
                )
            },
            to: baseURL.appendingPathComponent(type.path),
            method: type.method,
            headers: type.headers,
            interceptor: type.addAuth ? authInterceptor : nil
        )
    }

    public func downloadRequest(from url: String) -> DownloadRequest {
        let destination: DownloadRequest.Destination = DownloadRequest.suggestedDownloadDestination(options: .removePreviousFile)
        let downloadRequest = sessionManager.download(url, to: destination)

        return downloadRequest
    }

    public func handleResponse<T: Decodable>(_ response: AFDataResponse<Data>) -> Result<T, RequestError> {
        let result = processResponse(response)

        switch result {
            case .success(let data):
                do {
                    let object: T = try self.objectFromData(data)
                    return .success(object)
                } catch let error {
                    debugPrint("🆘 cannotDecodeOptionalContentData error: \(error).\(error.localizedDescription)")
                    return .failure(.decodingError(error))
                }
            case .failure(let error):
                debugPrint("🆘 response ended with error: \(error.localizedDescription)")
                return .failure(error)
        }
    }

    public func handleResponseOptionally<T: Decodable>(_ response: AFDataResponse<Data>) -> Result<T?, Error> {
        let result = processResponse(response)

        switch result {
            case .success(let data):
                if data.isEmpty {
                    return .success(nil)
                } else {
                    do {
                        let object: T = try self.objectFromData(data)
                        return .success(object)
                    } catch let error {
                        debugPrint("🆘 cannotDecodeOptionalContentData error: \(error). \(error.localizedDescription)")
                        return .failure(RequestError.decodingError(error))
                    }
                }
            case .failure(let error):
                debugPrint("🆘 response ended with error: \(error.localizedDescription)")
                return .failure(error)
        }
    }

    public func objectFromData<T: Decodable>(_ data: Data) throws -> T {
        do {
            let object = try self.decoder.decode(T.self, from: data)
            return object
        } catch DecodingError.dataCorrupted(let context) {
            throw DecodingError.dataCorrupted(context)
        } catch DecodingError.keyNotFound(let key, let context) {
            throw DecodingError.keyNotFound(key, context)
        } catch DecodingError.typeMismatch(let type, let context) {
            throw DecodingError.typeMismatch(type, context)
        } catch DecodingError.valueNotFound(let value, let context) {
            throw DecodingError.valueNotFound(value, context)
        } catch let error {
            throw error
        }
    }

    public func decodeRawError<T: ServerError>(_ data: Data) -> T? {
        do {
            let object = try self.decoder.decode(T.self, from: data)
            return object
        } catch let error {
            debugPrint(error.localizedDescription)
            return nil
        }
    }
}

// MARK: - Private Methods
private extension NetworkingSession {
    func processResponse(_ response: AFDataResponse<Data>) -> Result<Data, RequestError> {
        switch response.result {
            case .success(let data):
                guard
                    let responseType = response.response?.status?.responseType
                else {
                    return .failure(.some(URLError(.badServerResponse)))
                }

                switch responseType {
                    case .informational,
                            .success:
                        return .success(data)
                    case .redirection:
                        return .failure(.unknown)
                    case .clientError:
                        var errorMessage: String
                        if response.response?.status == .unauthorized {
                            errorMessage = "Unauthorized user"
                            onUnauthorizedInterceptor?()
                        }
                        if let rawError: RawError = self.decodeRawError(data) {
                            errorMessage = rawError.message
                        } else {
                            errorMessage = URLError(.badServerResponse).localizedDescription
                        }
                        return .failure(.clientError(
                            message: errorMessage,
                            code: response.response?.status)
                        )
                    case .serverError:
                        let errorMessage: String
                        if let rawError: RawError = self.decodeRawError(data) {
                            errorMessage = rawError.message
                        } else {
                            errorMessage = URLError(.badServerResponse).localizedDescription
                        }
                        return .failure(.serverError(
                            message: errorMessage,
                            code: response.response?.status)
                        )
                    case .undefined:
                        return .failure(.unknown)
                }
            case .failure(let error):
                return .failure(.some(error))
        }
    }

    private func appendMultipartData(_ multipartData: MultipartFormData, with dictionary: [String: Any]) {
        for (key, value) in dictionary {
            if let value = value as? String,
               let data = value.data(using: .utf8) {
                multipartData.append(data, withName: key)
            }
        }
    }
}

// MARK: - Encodable Extension
private extension Encodable {
    func asDictionary(encoder: JSONEncoder) -> [String: Any]? {
        do {
            let data = try encoder.encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]

            return dictionary
        } catch let error {
            debugPrint(error.localizedDescription)
            return nil
        }
    }
}
