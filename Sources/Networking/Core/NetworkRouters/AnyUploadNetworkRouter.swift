//
//  AnyUploadNetworkRouter.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

// MARK: - AnyUploadNetworkRouter
public protocol AnyUploadNetworkRouter {
    typealias Endpoint = String

    var uploadData: [MultipartUpload] { get }
    var path: Endpoint { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? { get }
    var addAuth: Bool { get }

    var overridenEncoder: JSONEncoder? { get }
    var overridenDecoder: JSONDecoder? { get }
}

public extension AnyUploadNetworkRouter {
    var method: HTTPMethod { .post }
    var headers: HTTPHeaders? {
        [
            HTTPHeader.accept("application/json"),
            HTTPHeader.contentType("multipart/form-data")
        ]
    }
    var addAuth: Bool { false }

    var overridenEncoder: JSONEncoder? { nil }
    var overridenDecoder: JSONDecoder? { nil }
}

// MARK: - FileMultipartEncodable
public protocol FileMultipartEncodable: Encodable {
    var fileURL: URL { get }
    var name: String { get }
    var fileName: String { get }
    var fileType: String { get }
    var mimeType: String { get }
}

public extension FileMultipartEncodable {
    var fileName: String { "" }
    var fileType: String { "" }
    var mimeType: String { "" }
}

// MARK: - DataMultipartEncodable
public protocol DataMultipartEncodable: Encodable { }

// MARK: - MultipartUpload
public enum MultipartUpload {
    case file(FileMultipartEncodable)
    case data(DataMultipartEncodable)
}
