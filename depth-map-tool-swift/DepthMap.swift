import Foundation
import CoreImage
import AVFoundation

class DepthMap {
    static func createAVDepthData(
        ciContext: CIContext = CIContext(),
        grayscaleImage: CIImage
    ) -> AVDepthData? {
        
        guard let pixelBuffer = createPixelBuffer(from: grayscaleImage, ciContext: ciContext) else {
            return nil
        }

        guard let depthPixelBuffer = convertToDepthPixelBuffer(from: pixelBuffer) else {
            return nil
        }

        return createAVDepthData(from: depthPixelBuffer)
    }

    private static func createPixelBuffer(from grayscaleImage: CIImage, ciContext: CIContext) -> CVPixelBuffer? {
        let scaledImage = grayscaleImage.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        let width = scaledImage.extent.width
        let height = scaledImage.extent.height
        
        var pixelBuffer: CVPixelBuffer?
        let attributes: CFDictionary = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey as String: kCFBooleanTrue!
        ] as CFDictionary
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else { return nil }
        
        // Render the CIImage to the pixel buffer
        ciContext.render(scaledImage, to: buffer)
        
        return buffer
    }

    private static func convertToDepthPixelBuffer(from pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let converter = GrayscaleToDepthConverter()
        return converter.render(input: pixelBuffer)
    }

    private static func createAVDepthData(from depthPixelBuffer: CVPixelBuffer) -> AVDepthData? {
        let targetPixelFormat = kCVPixelFormatType_DisparityFloat16

        let supportedFormats: [OSType] = [
            kCVPixelFormatType_DisparityFloat16
        ]

        guard supportedFormats.contains(targetPixelFormat) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthPixelBuffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBuffer)
        let totalBytes = bytesPerRow * CVPixelBufferGetHeight(depthPixelBuffer)
        
        guard let data = CFDataCreate(
            kCFAllocatorDefault,
            baseAddress.assumingMemoryBound(to: UInt8.self),
            totalBytes
        ) else {
            return nil
        }

        let metadata: [CFString: Any] = [
            kCGImagePropertyPixelFormat: targetPixelFormat,
            kCGImagePropertyWidth: CVPixelBufferGetWidth(depthPixelBuffer),
            kCGImagePropertyHeight: CVPixelBufferGetHeight(depthPixelBuffer),
            kCGImagePropertyBytesPerRow: bytesPerRow
        ]
        
        return createAVDepthData(from: data, metadata: metadata)
    }

    private static func createAVDepthData(from data: CFData, metadata: [CFString: Any]) -> AVDepthData? {
        do {
            let depthData = try AVDepthData(fromDictionaryRepresentation: [
                kCGImageAuxiliaryDataInfoData: data,
                kCGImageAuxiliaryDataInfoDataDescription: metadata
            ])
            return depthData
        } catch {
            print("Error creating AVDepthData: \(error)")
            return nil
        }
    }
}
