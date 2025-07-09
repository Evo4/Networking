//
//  NetworkingSession.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire
import Utility

public typealias Response<T: Decodable> = Result<T, NetworkingSession.RequestError>

// MARK: - NetworkingSession
open class NetworkingSession: NetworkingSessionProtocol {
    // MARK: - Public Properties
    public private(set) var sessionManager: Session

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
    public let decoder: JSONDecoder
    public let encoder: JSONEncoder

    private let rootQueue: DispatchQueue
    private let requestQueue: DispatchQueue
    private let serializationQueue: DispatchQueue
    private let configuration: URLSessionConfiguration

    private let authenticator: OAuthAuthenticator = .init()
    private var authInterceptor: AuthenticationInterceptor<OAuthAuthenticator>?
    private let eventMonitor: BaseEventMonitor = .init()
    private let requestInterceptor: BaseRequestInterceptor = .init()
    private let connectivity: Connectivity
    private var baseURL: URL

    // MARK: - Init
    public init(baseURL: URL, connectivity: Connectivity) {
        self.baseURL = baseURL

        self.connectivity = connectivity

        self.decoder = Self.configurateDecoder()
        self.encoder = Self.configurateEncoder()

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

        self.startup()
    }

    // MARK: - Private Static Methods
    private static func configurateDecoder() -> JSONDecoder {
        let decoder: JSONDecoder = .init()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    private static func configurateEncoder() -> JSONEncoder {
        let encoder: JSONEncoder = .init()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    // MARK: - Private Methods
    private func startup() {
        connectivity.startObserving()
    }

    // MARK: - Public Methods
    // MARK: - Make Request Methods
    open func makeRequest<Model: Decodable>(_ router: AnyNetworkRouter) async throws -> Model {
        let request = try tryRequest(router)
        let response = await request.asyncResponseData()
        let result: Response<Model> = handleResponse(response)

        switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
        }
    }

    open func makeMultipartRequest<Model: Decodable>(_ request: AnyUploadNetworkRouter) async throws -> Model {
        let request = try tryMultipartRequest(request)
        let response = await request.asyncResponseData()
        let result: Response<Model> = handleResponse(response)

        switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
        }
    }

    // MARK: - Try Request Methods
    public func tryRequest(_ type: AnyNetworkRouter) throws -> DataRequest {
        guard case .reachable = connectivity.isReachableValue else {
            var message = "🆘 Request ended with error."
            message.append("\nRequest: \(type.path)")
            message.append("\nError: \(RequestError.connectionLost), \(RequestError.connectionLost.errorDescription ?? "")")

            log.error(message)
            throw RequestError.connectionLost
        }

        let request = request(type)
        return request
    }

    public func tryMultipartRequest(_ type: AnyUploadNetworkRouter) throws -> UploadRequest {
        guard case .reachable = connectivity.isReachableValue else {
            log.error("🆘 Request ended with error. \(RequestError.connectionLost): \(RequestError.connectionLost.errorDescription ?? "")")
            throw RequestError.connectionLost
        }

        let request = multipartRequest(type)
        return request
    }

    // MARK: - Base Request Methods
    public func request(_ type: AnyNetworkRouter) -> DataRequest {
        let encoder = type.overridenEncoder ?? self.encoder
        let parameters: Parameters? = type.parameters?.asDictionary(encoder: encoder)

        return sessionManager.request(
            baseURL.appendingPathComponent(type.path),
            method: type.method,
            parameters: parameters,
            encoding: type.encoder,
            headers: type.headers,
            interceptor: type.addAuth ? authInterceptor : nil
        )
    }

    public func multipartRequest(_ type: AnyUploadNetworkRouter) -> UploadRequest {
        sessionManager.upload(
            multipartFormData: { [weak self] multipartFormData in
                self?.appendMultipartData(
                    multipartFormData,
                    with: type.uploadData,
                    overridenEncoder: type.overridenEncoder
                )
            },
            to: baseURL.appendingPathComponent(type.path),
            method: type.method,
            headers: type.headers,
            interceptor: type.addAuth ? authInterceptor : nil
        )
    }

    public func downloadStream(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options
    ) -> DownloadStream {
        downloadRequest(from: url, to: destinationFolderURL, options: options).buildStream()
    }

    public func downloadRequest(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options
    ) -> DownloadRequest {
        let destination: DownloadRequest.Destination = { temporaryURL, response in
            let filename = response.suggestedFilename ?? "file.\(UUID().uuidString)"
            let url = destinationFolderURL?.appendingPathComponent(filename) ?? temporaryURL

            return (url, options)
        }
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
                    log.error("🆘 CannotDecodeOptionalContentData error: \(error).\(error.localizedDescription). Decodable type: \(T.self)")
                    return .failure(.decodingError(error))
                }
            case .failure(let error):
                log.error("🆘 Response ended with error: \(error). \(error.localizedDescription)")
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
                        log.error("🆘 CannotDecodeOptionalContentData error: \(error). \(error.localizedDescription). Decodable type: \(T.self)")
                        return .failure(RequestError.decodingError(error))
                    }
                }
            case .failure(let error):
                log.error("🆘 Response ended with error: \(error.localizedDescription)")
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

    public func decodeRawError<T: ServerError>(_ data: Data) throws -> T {
        try self.decoder.decode(T.self, from: data)
    }
}

// MARK: - Private Methods
private extension NetworkingSession {
    func processResponse(_ response: AFDataResponse<Data>) -> Result<Data, RequestError> {
        switch response.result {
            case .success(let data):
                guard
                    let status = response.response?.status
                else {
                    return .failure(RequestError.unknown)
                }

                let responseType = status.responseType
                switch responseType {
                    case .informational,
                            .success:
                        return .success(data)
                    case .redirection:
                        return .failure(RequestError.redirected)
                    case .clientError:
                        if status == .unauthorized {
                            onUnauthorizedInterceptor?()
                            return .failure(.unauthorized)
                        }
                        do {
                            let rawError: RawError = try decodeRawError(data)
                            return .failure(.clientError(
                                message: rawError.message,
                                code: status
                            ))
                        } catch {
                            return .failure(.decodingError(error))
                        }
                    case .serverError:
                        do {
                            let rawError: RawError = try decodeRawError(data)
                            return .failure(.serverError(
                                message: rawError.message,
                                code: status
                            ))
                        } catch {
                            return .failure(.decodingError(error))
                        }
                    case .undefined:
                        return .failure(.unknown)
                }
            case .failure(let error):
                switch error {
                    case .sessionTaskFailed(error: let error):
                        if let urlError = error as? URLError {
                            switch urlError.code {
                                case .notConnectedToInternet:
                                    return .failure(.connectionLost)
                                case .networkConnectionLost:
                                    return .failure(.connectionLost)
                                case .timedOut:
                                    return .failure(.requestFailed(message: "The operation timed out. Please try again."))
                                case .resourceUnavailable:
                                    return .failure(.requestFailed(message: "The resource is unavailable. Please try again later"))
                                case .serverCertificateUntrusted, .secureConnectionFailed:
                                    return .failure(.requestFailed(message: "Сannot establish secure connection. Please try again later."))
                                default:
                                    break
                            }
                        }
                        return .failure(.requestFailed(message: "Something went wrong. Please try again."))
                    case .explicitlyCancelled:
                        return .failure(.requestExplicitlyCancelled)
                    case .requestAdaptationFailed(let error):
                        if let error = error as? RequestError {
                            return .failure(error)
                        }
                        fallthrough
                    default:
                        return .failure(.some(error))
                }
        }
    }

    func appendMultipartData(
        _ multipartData: MultipartFormData,
        with uploadData: [MultipartUpload],
        overridenEncoder: JSONEncoder? = nil
    ) {
        let encoder = overridenEncoder ?? self.encoder

        for data in uploadData {
            switch data {
                case .file(let fileMultipartEncodable):
                    guard
                        let inputStream = InputStream(url: fileMultipartEncodable.fileURL)
                    else { return }

                    multipartData.append(
                        inputStream,
                        withLength: UInt64(fileMultipartEncodable.fileURL.fileSize),
                        name: fileMultipartEncodable.name,
                        fileName: fileMultipartEncodable.fileName,
                        mimeType: fileMultipartEncodable.mimeType
                    )
                case .data(let dataMultipartEncodable):
                    guard let dictionary = dataMultipartEncodable.asDictionary(encoder: encoder) else { return }

                    appendMultipartData(multipartData, with: dictionary)
            }
        }
    }

    func appendMultipartData(_ multipartData: MultipartFormData, with dictionary: [String: Any]) {
        for (key, value) in dictionary {
            switch value {
                case let value as String:
                    if let data = value.data(using: .utf8) {
                        multipartData.append(data, withName: key)
                    }
                case let value as Bool:
                    let string = String(value)
                    if let data = string.data(using: .utf8) {
                        multipartData.append(data, withName: key)
                    }
                case let value as [String: Any]:
                    do {
                        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .prettyPrinted])
                        multipartData.append(data, withName: key)
                    } catch {
                        log.error("Cannot decode nested object: \(error.localizedDescription). \nObject: \(value)")
                    }
                default:
                    continue
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
            log.error(error.localizedDescription)
            return nil
        }
    }
}
