//
//  NetworkingSession+RawError.swift
//  Networking
//
//  Created by Vyacheslav Razumeenko on 08.06.2025.
//

import Foundation

// MARK: - ServerError
public typealias ServerError = Decodable & Error

// MARK: - ErrorObject
public struct RawError: ServerError {
    public let message: String
}
