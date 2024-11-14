//
//  NetworkingEventMonitor.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire
import Utility

final class BaseEventMonitor: EventMonitor {
    let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "").networklogger")

    func requestDidFinish(_ request: Request) {
        guard let statusCode = request.response?.statusCode else {
            log.error("⛔️ Cancel: \(request.description)")
            return
        }

        log.debug("\n✅ \(request.description)\n🔸 Status code: \(statusCode)")
    }

    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        guard
            let data = response.data
        else {
            log.error("\n🔸 Data: nil")
            return
        }

        log.debug("\n🔸 Data: \(data.prettyPrintedJSONString ?? .init())")

        do {
            let _ = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            log.debug("\n👍🏼 Serialization: OK")
        } catch let error {
            log.error("‼️ Serialization: \(error.localizedDescription)")
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        debugPrint(progress)
    }
}
