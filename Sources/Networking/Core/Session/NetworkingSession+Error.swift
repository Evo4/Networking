//
//  File.swift
//  
//
//  Created by Vyacheslav Razumeenko on 05.09.2024.
//

import Foundation

// MARK: - RequestError
extension NetworkingSession {
    public enum RequestError: LocalizedError {
        /// `URLSessionTask` completed with unknown response.
        case unknown
        case some(Swift.Error)
        case clientError(message: String, code: HTTPURLResponse.HTTPStatusCode)
        case serverError(message: String, code: HTTPURLResponse.HTTPStatusCode)
        case decodingError(Swift.Error)
        case connectionLost
        /// `URLSessionTask` completed with error. Indicated low level connection issues.
        /// Thats means that request doesn't reach server and returns with connection error.
        case requestFailed(message: String)
        /// `Request` was explicitly cancelled manually.
        case requestExplicitlyCancelled
        case unauthorized
        case redirected

        public var errorDescription: String? {
            switch self {
                case .unknown:
                    return "Unknown error."
                case let .some(error):
                    return error.localizedDescription
                case let .clientError(message, code):
                    return "CLIENT ERROR. Code: \(code.rawValue). \(message)"
                case let .serverError(message, code):
                    return "SERVER ERROR. Code: \(code.rawValue). \(message)"
                case let .decodingError(error):
                    return "Decoding error. \(error)"
                case .connectionLost:
                    return "Internet connection is unreachable."
                case .requestFailed(let message):
                    return message
                case .requestExplicitlyCancelled:
                    return "Request explicitly cancelled."
                case .unauthorized:
                    return "User unauthorized."
                case .redirected:
                    return "Redirected."
            }
        }
    }
}
