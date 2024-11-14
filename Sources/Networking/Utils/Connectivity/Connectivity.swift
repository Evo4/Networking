//
//  Connectivity.swift
//
//
//  Created by Vyacheslav Razumeenko on 05.09.2024.
//

import Foundation
import Combine

public protocol Connectivity: AnyObject {
    var isReachable: AnyPublisher<ConnectivityImpl.Status, Never> { get }
    var isReachableValue: ConnectivityImpl.Status { get }
    var isReachableFlag: Bool { get }

    func startObserving()
    func stopObserving()
}
