//
//  main.swift
//  depth-map-tool-swift
//
//  Created by Nils Hodys on 02.03.25.
//

import Foundation
import CoreImage
import UniformTypeIdentifiers

// Check if the correct number of arguments is provided
guard CommandLine.arguments.count == 4 else {
    print("Usage: \(CommandLine.arguments[0]) <baseImageUrl> <depthImageUrl> <outputUrl>")
    exit(1)
}

// Retrieve the command line arguments
let baseImageUrl = URL(fileURLWithPath: CommandLine.arguments[1])
let depthImageUrl = URL(fileURLWithPath: CommandLine.arguments[2])
let outputUrl = URL(fileURLWithPath: CommandLine.arguments[3])

do {
    let inputBaseCGImage = await File.loadImage(url: baseImageUrl)
    let inputDepthCGImage = await File.loadImage(url: depthImageUrl)
    
    guard let depthData = try DepthMap.createAVDepthData(
        grayscaleImage: CIImage(cgImage: inputDepthCGImage!)
    ) else {
        throw AppError("Failed to get depth data")
    }
    
    var auxDataType: NSString?
    
    let auxiliaryData = (depthData.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType))! as CFDictionary
    
    try File.saveImage(
        file: outputUrl,
        cgImage: inputBaseCGImage!,
        utType: UTType.heic,
        auxiliaryData: auxiliaryData
    )
    
    print("Image saved successfully to \(outputUrl.path)")
} catch {
    print("Error: \(error)")
}
