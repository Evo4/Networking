//
//  TokenRouter.swift
//  
//
//  Created by Vyacheslav Razumeenko on 18.08.2024.
//

import Foundation

public extension TokenManager {
    enum TokenRouter {
        case refreshToken(TokenManager.TokensModel)
    }
}

//extension TokenManager.TokenRouter: AnyNetworkRouter {
//    public var path: Endpoint {
//        switch self {
//            case .refreshToken:
//                return "refresh_token"
//        }
//    }
//
//    public var method: HTTPMethod {
//        switch self {
//            case .refreshToken:
//                return .post
//        }
//    }
//
//    public var parameters: Encodable? {
//        switch self {
//            case .refreshToken(let refreshTokenModel):
//                return refreshTokenModel
//        }
//    }
//}
