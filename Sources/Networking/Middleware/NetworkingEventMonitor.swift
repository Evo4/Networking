//
//  NetworkingEventMonitor.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

final class BaseEventMonitor: EventMonitor {
    let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "").networklogger")

    func requestDidFinish(_ request: Request) {
        guard let statusCode = request.response?.statusCode else {
            debugPrint("⛔️ Cancel: \(request.description)")
            return
        }

        debugPrint("==========================")
        debugPrint("✅ \(request.description)")
        debugPrint("🔸 Stutus code: \(statusCode)")
    }

    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        guard
            let data = response.data
        else {
            debugPrint("🔸 Data: nil")
            debugPrint("==========================")
            return
        }

        debugPrint("🔸 Data:", data.prettyPrintedJSONString ?? .init())

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
//            debugPrint("👍🏼 Serialization:", json)
            debugPrint("👍🏼 Serialization: OK")
        } catch let error {
            debugPrint("‼️ Serialization: \(error.localizedDescription)")
        }
        debugPrint("==========================")
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

    func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        switch uploadable {
            case .data(let data):
                let string = data.toString
                debugPrint("🔸 Uploading data:", string)
            case .file(let uRL, let shouldRemove):
                debugPrint("🔸 Uploading url:", uRL)
                debugPrint("🔸 With removing: \(shouldRemove)")
            case .stream(let inputStream):
                debugPrint("🔸 Uploading stream:", inputStream)
        }

        debugPrint("")
    }
}
