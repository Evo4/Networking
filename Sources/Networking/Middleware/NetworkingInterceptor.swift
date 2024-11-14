//
//  NetworkingInterceptor.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire
import Utility

final class BaseRequestInterceptor: RequestInterceptor {
    public weak var delegate: InterceptorDelegate?

    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        guard
            let delegate = delegate
        else {
            completion(.success(urlRequest))
            return
        }

        let headerData = try? JSONSerialization.data(
            withJSONObject: urlRequest.allHTTPHeaderFields ?? [:],
            options: .prettyPrinted
        )
        let header = headerData?.prettyPrintedJSONString ?? .init()

        var message = "Request:"
        message.append("\n🏃🏼‍♂️ \(urlRequest.httpMethod ?? "nil") \(urlRequest.debugDescription)")
        message.append("\n🔸 Header: \(header)")
        message.append("\n🔸 Parameters:, \(urlRequest.httpBody?.prettyPrintedJSONString ?? "nil")")
        log.debug(message)

        delegate.adapt(urlRequest, completion: completion)
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard
            request.response?.status != .ok
        else {
            completion(.doNotRetry)
            return
        }

        var message = "\n❌ Failure: \(request.description)"
        message.append("\n🔄 Retry count: \(request.retryCount)")
        message.append("\n🔸 Error: \(error.localizedDescription)")
        log.error(message)

        guard
            let delegate = delegate
        else {
            completion(.doNotRetry)
            return
        }

        delegate.retry(request, dueTo: error, completion: completion)
    }
}
