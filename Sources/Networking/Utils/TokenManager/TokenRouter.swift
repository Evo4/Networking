//
//  TokenRouter.swift
//  
//
//  Created by Vyacheslav Razumeenko on 18.08.2024.
//

import Foundation

public extension TokenManager {
    // MARK: - TokensResponse
    struct TokensResponse: Decodable {
        let data: TokensModel
    }

    // MARK: - TokensModel
    struct TokensModel: Codable {
        public var access: String
        public var refresh: String

        public init(access: String, refresh: String) {
            self.access = access
            self.refresh = refresh
        }
    }

    // MARK: - RefreshTokenModel
    struct RefreshTokenModel: Codable {
        var refresh: String
    }

    enum TokenRouter {
        case refreshToken(TokenManager.RefreshTokenModel)
    }
}

extension TokenManager.TokenRouter: AnyNetworkRouter {
    public var path: Endpoint {
        switch self {
            case .refreshToken:
                return "refresh_token"
        }
    }

    public var method: HTTPMethod {
        switch self {
            case .refreshToken:
                return .post
        }
    }

    public var parameters: Encodable? {
        switch self {
            case .refreshToken(let refreshTokenModel):
                return refreshTokenModel
        }
    }
}
