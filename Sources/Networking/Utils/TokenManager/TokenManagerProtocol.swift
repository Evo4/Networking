//
//  TokenManagerProtocol.swift
//  
//
//  Created by Vyacheslav Razumeenko on 18.08.2024.
//

// MARK: - Token Protocol
public protocol TokenManagerProtocol: AnyObject {
    typealias Tokens = TokenManager.TokensModel

    func updateToken(_ tokens: Tokens?)
}
