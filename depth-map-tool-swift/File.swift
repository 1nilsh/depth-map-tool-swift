//
//  File.swift
//  depth-map-tool-swift
//
//  Created by Nils Hodys on 02.03.25.
//

import Foundation
import AVFoundation

class File {
    static func saveImage(file: URL, cgImage: CGImage, utType: UTType, auxiliaryData: CFDictionary?) throws {
        guard let dest = CGImageDestinationCreateWithURL(file as CFURL, utType.identifier as CFString, 1, nil) else {
            throw FileError("Failed to create image destination")
        }
        
        CGImageDestinationAddImage(dest, cgImage, nil)
        
        CGImageDestinationAddAuxiliaryDataInfo(dest, kCGImageAuxiliaryDataTypeDisparity, auxiliaryData!)
        
        if !CGImageDestinationFinalize(dest) {
            throw AppError("CGImageDestinationFinalize failed")
        }
    }
    
    static func loadImage(url: URL) async -> CGImage? {
        let _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
