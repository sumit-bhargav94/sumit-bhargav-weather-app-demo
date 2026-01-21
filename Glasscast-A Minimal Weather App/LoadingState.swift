//
//  LoadingState.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
