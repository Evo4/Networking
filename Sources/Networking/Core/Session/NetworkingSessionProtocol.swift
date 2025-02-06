//
//  NetworkingSessionProtocol.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

public protocol NetworkingSessionProtocol: AnyObject {
    var sessionManager: Session { get }
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }

    var authCredential: OAuthAuthenticator.OAuthCredential? { get set }
    var authDelegate: OAuthAuthenticatorDelegate? { get set }
    var interceptorDelegate: InterceptorDelegate? { get set }
    var onUnauthorizedInterceptor: (() -> Void)? { get set }

    func makeRequest<Model: Decodable>(_ router: AnyNetworkRouter) async throws -> Model
    func makeMultipartRequest<Model: Decodable>(
        _ request: AnyNetworkRouter,
        appendWith dictionary: [String: Any]
    ) async throws -> Model
    func makeMultipartRequest<Model: Decodable>(
        _ request: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) async throws -> Model

    func tryRequest(_ type: AnyNetworkRouter) throws -> DataRequest
    func tryMultipartRequest(
        _ type: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) throws -> UploadRequest

    func request(_ type: AnyNetworkRouter) -> DataRequest?
    func multipartRequest(
        _ type: AnyNetworkRouter,
        appendMultipartData: @escaping ((_ multipartFormData: MultipartFormData) -> Void)
    ) -> UploadRequest?

    func uploadFile(_ type: AnyUploadNetworkRouter) -> DataRequest?

    func downloadRequest(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options
    ) -> DownloadRequest
    func downloadStream(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options
    ) -> DownloadStream

    func handleResponse<T: Decodable>(_ response: AFDataResponse<Data>) -> Result<T, NetworkingSession.RequestError>
    func handleResponseOptionally<T: Decodable>(_ response: AFDataResponse<Data>) -> Result<T?, Error>

    func objectFromData<T: Decodable>(_ data: Data) throws -> T
    func decodeRawError<T: ServerError>(_ data: Data) -> T?
}

public extension NetworkingSessionProtocol {
    func downloadRequest(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options = [.removePreviousFile, .createIntermediateDirectories]
    ) -> DownloadRequest {
        downloadRequest(from: url, to: destinationFolderURL, options: options)
    }

    func downloadStream(
        from url: String,
        to destinationFolderURL: URL?,
        options: DownloadRequest.Options = [.removePreviousFile, .createIntermediateDirectories]
    ) -> DownloadStream {
        downloadStream(
            from: url,
            to: destinationFolderURL,
            options: options
        )
    }
}
