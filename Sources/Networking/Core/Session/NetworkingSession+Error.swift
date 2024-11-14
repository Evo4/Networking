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
        case unknown
        case some(Swift.Error)
        case clientError(message: String, code: HTTPURLResponse.HTTPStatusCode?)
        case serverError(message: String, code: HTTPURLResponse.HTTPStatusCode?)
        case decodingError(Swift.Error)
        case connectionLost
        case userCanceledSignInFlow
        case requestFailed(message: String)
        case requestExplicitlyCancelled

        public var errorDescription: String? {
            switch self {
                case .unknown:
                    return "Unknown error"
                case let .some(error):
                    return error.localizedDescription
                case let .clientError(message, code):
                    return "CLIENT ERROR. Code: \(code?.rawValue ?? 0). \(message)"
                case let .serverError(message, code):
                    return "SERVER ERROR. Code: \(code?.rawValue ?? 0). \(message)"
                case let .decodingError(description):
                    return "Decoding error. \(description)"
                case .connectionLost:
                    return "Internet connection is unreachable"
                case .userCanceledSignInFlow:
                    return "User canceled sign in flow"
                case .requestFailed(let message):
                    return message
                case .requestExplicitlyCancelled:
                    return "Request explicitly cancelled"
            }
        }
    }
}
