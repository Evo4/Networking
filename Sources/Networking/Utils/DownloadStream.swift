//
//  DownloadStream.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

// MARK: - DownloadStream
public class DownloadStream: NSObject {
    // MARK: - Event
    public enum Event {
        case progress(progress: Progress)
        case success(url: URL)
        case error(AFError)
    }

    // MARK: - Public Properties
    public var events: AsyncStream<Event> {
        AsyncStream { continuation in
            self.continuation = continuation
            Task {
                await download()
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.task?.cancel()
            }
        }
    }

    // MARK: - Private Properties
    private let request: DownloadRequest
    private var continuation: AsyncStream<Event>.Continuation?
    private var task: DownloadTask<URL>?

    // MARK: - Init
    public init(request: DownloadRequest) {
        self.request = request
        super.init()
    }

    public func pause() {
        task?.suspend()
    }

    public func resume() {
        task?.resume()
    }
}

// MARK: - Private Properties
private extension DownloadStream {
    func download() async {
        Task {
            for await progress in request.downloadProgress() {
                continuation?.yield(.progress(progress: progress))
            }
        }

        let task = request.serializingDownloadedFileURL()
        self.task = task

        let result = await task.result

        switch result {
            case .success(let data):
                continuation?.yield(.success(url: data))
            case .failure(let error):
                continuation?.yield(.error(error))
        }
    }
}
