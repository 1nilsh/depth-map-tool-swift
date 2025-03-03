//
//  Errors.swift
//  depth-map-tool-swift
//
//  Created by Nils Hodys on 02.03.25.
//

struct AppError: Error {
    let message: String
    
    init(_ message: String = "") {
        self.message = message
    }
}

struct FileError: Error {
    let message: String
    
    init(_ message: String = "") {
        self.message = message
    }
}
