//
//  Date+Extension.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation

public extension Date {
    static func - (lhs: Date, rhs: Date) -> Date {
        .init(timeIntervalSinceReferenceDate: lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate)
    }
}
