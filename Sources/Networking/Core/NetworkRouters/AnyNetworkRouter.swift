//
//  AnyNetworkRouter.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

public enum RequestRouter { }

// MARK: - Networking Router Protocol
public protocol AnyNetworkRouter {
    typealias Endpoint = String
    typealias HTTPHeaders = Alamofire.HTTPHeaders
    typealias HTTPMethod = Alamofire.HTTPMethod

    var path: Endpoint { get }
    var method: HTTPMethod { get }
    var parameters: Encodable? { get }
    var encoder: ParameterEncoding { get }
    var headers: HTTPHeaders? { get }
    var addAuth: Bool { get }
    var data: Data? { get }

    var withSnakeStyleEncoder: Bool { get }
}

public extension AnyNetworkRouter {
    var parameters: Encodable? { nil }
    var headers: HTTPHeaders? { ["Accept": "application/json"] }
    var addAuth: Bool { false }
    var data: Data? { nil }

    var encoder: ParameterEncoding {
        switch method {
            case .get:
                return URLEncoding.default
            case .post:
                return JSONEncoding.default
            default:
                return JSONEncoding.default
        }
    }

    var withSnakeStyleEncoder: Bool { true }
}
