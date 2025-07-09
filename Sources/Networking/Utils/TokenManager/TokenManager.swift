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
import Utility

// MARK: - TokenManager
open class TokenManager: TokenManagerProtocol {
    // MARK: - Private Properties
    private let keychainStore: AnyStorage<KeychainStore>
    private let rest: NetworkingSessionProtocol

    private var authCredential: OAuthAuthenticator.OAuthCredential? {
        guard
            let accessToken: String = keychainStore.get(.accessToken),
            let expirationDate: Date = expirationDate(token: accessToken)
        else {
            return nil
        }

        return .init(
            accessToken: accessToken,
            refreshToken: keychainStore.get(.refreshToken) ?? "",
            accessTokenExpiration: expirationDate
        )
    }

    // MARK: - Init
    public init(rest: NetworkingSessionProtocol, keychainStore: AnyStorage<KeychainStore>) {
        self.rest = rest
        self.keychainStore = keychainStore

        self.commonSetup()
    }

    // MARK: - TokenManagerProtocol
    public func updateToken(_ tokens: TokensModel?) {
        guard
            let tokens = tokens
        else {
            rest.authCredential = nil
            return
        }

        keychainStore.set(tokens.access, key: .accessToken)
        keychainStore.set(tokens.refresh, key: .refreshToken)

        rest.authCredential = self.authCredential
    }
}

// MARK: - Private Methods
private extension TokenManager {
    func commonSetup() {
        self.rest.authDelegate = self
        self.rest.authCredential = authCredential
    }

    func configAuthCredential(tokensModel: TokensModel) -> OAuthAuthenticator.OAuthCredential? {
        let accessToken = tokensModel.access
        guard
            let expirationDate = expirationDate(token: accessToken)
        else {
            return nil
        }

        let authCredential: OAuthAuthenticator.OAuthCredential = .init(
            accessToken: accessToken,
            refreshToken: tokensModel.refresh,
            accessTokenExpiration: expirationDate
        )

        self.keychainStore.set(accessToken, key: .accessToken)
        self.keychainStore.set(tokensModel.refresh, key: .refreshToken)

        return authCredential
    }

    func expirationDate(token: String) -> Date? {
        do {
            let jwt = try decode(jwt: token)
            return jwt.expiresAt
        } catch let error {
            debugPrint(error.localizedDescription)
            return nil
        }
    }

    func refreshTokenRequest(refreshToken: String?, completion: @escaping (Result<OAuthAuthenticator.OAuthCredential, Error>) -> Void) {
        guard
            let refreshToken = refreshToken,
            let isExpired = try? decode(jwt: refreshToken).expired,
            !isExpired
        else {
            let error = NetworkingSession.RequestError.unauthorized
            completion(.failure(error))
            return
        }

        let model: RefreshTokenModel = .init(refresh: refreshToken)
        let request = rest.request(TokenRouter.refreshToken(model))
        request.responseData { [weak self] response in
            guard let self = self else { return }

            switch response.result {
                case .success(let data):
                    do {
                        let tokensResponse: TokensResponse = try self.rest.objectFromData(data)
                        guard
                            let authCredential = self.configAuthCredential(tokensModel: tokensResponse.data)
                        else {
                            let error = NetworkingSession.RequestError.unknown
                            log.error(error.localizedDescription)
                            completion(.failure(error))
                            return
                        }

                        completion(.success(authCredential))
                    } catch let error {
                        let error = NetworkingSession.RequestError.decodingError(error)
                        log.error(error.localizedDescription)
                        completion(.failure(error))

                        return
                    }
                case .failure(let error):
                    log.error(error.localizedDescription)
                    completion(.failure(error))
                    return
            }
        }
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

    public func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: any Error) -> Bool {
        log.debug("urlRequest: \(urlRequest),\nresponse: \(response)")

        return false
    }
}
