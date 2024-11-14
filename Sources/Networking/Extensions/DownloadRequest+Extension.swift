//
//  DownloadRequest+Extension.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

public extension DownloadRequest {
    func buildStream() -> DownloadStream {
        DownloadStream(request: self)
    }
}
