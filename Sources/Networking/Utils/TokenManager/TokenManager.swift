//
//  TokenManager.swift
//  
//
//  Created by Vyacheslav Razumeenko on 18.08.2024.
//

import Foundation
import Alamofire
import JWTDecode
import Storage

open class TokenManager: TokenManagerProtocol {
    public struct TokensModel: Codable {
        public var accessToken: String?
        public var refreshToken: String?

        public init(accessToken: String?, refreshToken: String?) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    private let keychainStore: AnyStorage<KeychainStore>
    private let rest: NetworkingSessionProtocol

    private var authCredential: OAuthAuthenticator.OAuthCredential? {
        guard
            let accessToken: String = keychainStore.get(.accessToken)// ,
//            let expirationDate: Date = expirationDate(token: accessToken)
        else {
            return nil
        }

        return .init(
            accessToken: accessToken,
            refreshToken: keychainStore.get(.refreshToken) ?? "",
            expiration: .now
        )
    }

    public init(rest: NetworkingSessionProtocol, keychainStore: AnyStorage<KeychainStore>) {
        self.rest = rest
        self.keychainStore = keychainStore

        self.commonSetup()
    }

    private func commonSetup() {
        self.rest.authDelegate = self
        self.rest.authCredential = authCredential
    }

    private func configAuthCredential(tokensModel: TokensModel) -> OAuthAuthenticator.OAuthCredential? {
        guard
            let accessToken = tokensModel.accessToken// ,
//            let expirationDate = expirationDate(token: accessToken)
        else {
            return nil
        }

        let authCredential: OAuthAuthenticator.OAuthCredential = .init(
            accessToken: accessToken,
            refreshToken: tokensModel.refreshToken ?? "",
//            expiration: expirationDate
            expiration: .now
        )

        self.keychainStore.set(accessToken, key: .accessToken)
        self.keychainStore.set(tokensModel.refreshToken, key: .refreshToken)

        return authCredential
    }

    private func expirationDate(token: String) -> Date? {
        do {
            let jwt = try decode(jwt: token)
            return jwt.expiresAt
        } catch let error {
            debugPrint(error.localizedDescription)
            return nil
        }
    }

    public func refreshTokenRequest(refreshToken: String?, completion: @escaping (Result<OAuthAuthenticator.OAuthCredential, Error>) -> Void) {
        guard
            let refreshToken = refreshToken,
//            let isExpired = try? decode(jwt: refreshToken).expired,
//            !isExpired,
            let model = TokenRouter.refreshToken(.init(accessToken: nil, refreshToken: refreshToken)) as? AnyNetworkRouter,
            let request = rest.request(model)
        else {
            completion(.failure(URLError(.cancelled)))
            return
        }

        request.responseData { [weak self] response in
            guard let self = self else { return }

            switch response.result {
                case .success(let data):
                    do {
                        let tokensModel: TokensModel = try self.rest.objectFromData(data)

                        guard
                            let authCredential = self.configAuthCredential(tokensModel: tokensModel)
                        else {
                            completion(.failure(URLError(.badServerResponse)))
                            return
                        }

                        completion(.success(authCredential))
                    } catch let error {
                        debugPrint("cannotDecodeRefreshToken error: \(error)")
                        completion(.failure(URLError(.badServerResponse)))
                        return
                    }
                case .failure(let error):
                    completion(.failure(error))
                    return
            }
        }
    }

    // MARK: - TokenManagerProtocol
    public func updateToken(_ tokens: TokensModel?) {
        guard
            let tokens = tokens
        else {
            rest.authCredential = nil
            return
        }

        keychainStore.set(tokens.accessToken, key: .accessToken)
        keychainStore.set(tokens.refreshToken, key: .refreshToken)

        rest.authCredential = self.authCredential
    }
}

// MARK: - OAuthAuthenticatorDelegate
extension TokenManager: OAuthAuthenticatorDelegate {
    public func apply(_ credential: AuthCredential, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }

    public func refresh(credential: AuthCredential, completion: @escaping (Result<AuthCredential, Error>) -> Void) {
        self.refreshTokenRequest(refreshToken: credential.refreshToken, completion: completion)
    }
}
