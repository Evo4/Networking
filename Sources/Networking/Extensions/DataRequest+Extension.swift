//
//  DataRequest+Extension.swift
//
//
//  Created by Vyacheslav Razumeenko on 01.08.2024.
//

import Foundation
import Alamofire

public extension DataRequest {
    func asyncResponseData(
        queue: DispatchQueue = .main,
        dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
        emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
        emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods
    ) async -> AFDataResponse<Data> {
        await withCheckedContinuation { continuation in
            self.responseData(
                queue: queue,
                dataPreprocessor: dataPreprocessor,
                emptyResponseCodes: emptyResponseCodes,
                emptyRequestMethods: emptyRequestMethods
            ) { response in
                continuation.resume(returning: response)
            }
        }
    }
}
