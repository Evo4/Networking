//
//  InterceptorProtocol.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

// MARK: - InterceptorDelegate
public protocol InterceptorDelegate: AnyObject {
    typealias Request = Alamofire.Request
    typealias RetryResult = Alamofire.RetryResult

    func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void)
    func retry(_ request: Request, dueTo error: Error, completion: @escaping (RetryResult) -> Void)
}

public extension InterceptorDelegate {
    func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }

    func retry(_ request: Request, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        completion(.doNotRetry)
    }
}
