//
//  ConnectivityImpl.swift
//  
//
//  Created by Vyacheslav Razumeenko on 05.09.2024.
//

import Foundation
import Alamofire
import Combine

public class ConnectivityImpl: Connectivity {
    public typealias Status = NetworkReachabilityManager.NetworkReachabilityStatus

    // MARK: - Public Properties
    public var isReachable: AnyPublisher<Status, Never> { _isReachable.eraseToAnyPublisher() }
    public var isReachableValue: Status { _isReachable.value }
    public var isReachableFlag: Bool {
        if case .reachable = _isReachable.value {
            true
        } else {
            false
        }
    }

    // MARK: - Private Properties
    private let manager: NetworkReachabilityManager? = .init()
    private var _isReachable: CurrentValueSubject<Status, Never> = .init(.unknown)

    // MARK: - Init
    public init() {
        configure()
    }

    // MARK: - Public Methods
    public func startObserving() {
        manager?.startListening { [weak self] status in
            guard let self = self else { return }

            self._isReachable.send(status)
        }
    }

    public func stopObserving() {
        manager?.stopListening()
    }

    // MARK: - Private Methods
    private func configure() {
        if let status = manager?.status {
            _isReachable.send(status)
        }
    }
}
