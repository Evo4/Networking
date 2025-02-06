//
//  AnyNetworkTarget.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

/// Uses to build concrete service entity.
public protocol AnyNetworkTarget {
    var restClient: NetworkingSessionProtocol { get }
}
