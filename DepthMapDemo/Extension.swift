//
//  Extension.swift
//  DepthMapDemo
//
//  Created by Florian Wolpert on 20.12.20.
//

import Foundation
import CoreImage


extension CVPixelBuffer {
    func sinus(withMaxDepth maxDepth: Float, andFrequence frequence :Float) {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
        
        /// You might be wondering why the for loops below use `stride(from:to:step:)`
        /// instead of a simple `Range` such as `0 ..< height`?
        /// The answer is because in Swift 5.1, the iteration of ranges performs badly when the
        /// compiler optimisation level (`SWIFT_OPTIMIZATION_LEVEL`) is set to `-Onone`,
        /// which is eactly what happens when running this sample project in Debug mode.
        /// If this was a production app then it might not be worth worrying about but it is still
        /// worth being aware of.
        
        for y in stride(from: 0, to: height, by: 1) {
            for x in stride(from: 0, to: width, by: 1) {
                
                var pixel = floatBuffer[y * width + x]
                if pixel > maxDepth {  // clipping ab maxDepth
                    pixel = 0
                } else {
                    pixel /= maxDepth  // Normalisieren auf Werte zw. 0-1
                }
                
                pixel = min(1.0, max(pixel, 0.0)) // Wertebereich (0-1) sicherstellen
                floatBuffer[y * width + x] = sin(pixel*frequence)+1.0/2.0 // sinus mit hoher frequenz und transponiert in den Wertebereich von 0-1
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    
    func exportAsArray() -> [[Float32]] {

        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        var floatArray = Array(repeating: Array(repeating: Float32(0.0), count: height), count: width)
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
        
        for y in stride(from: 0, to: height, by: 1) {
            for x in stride(from: 0, to: width, by: 1) {
                floatArray[x][y] = floatBuffer[y * width + x]
            }
        }
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        return floatArray
    }
}

