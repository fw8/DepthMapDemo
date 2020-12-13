//
//  ViewController.swift
//  DepthMapDemo
//
//  Created by Carlotta Roedling on 08.12.20.
//

import UIKit
import Metal
import ARKit
import CoreGraphics

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    

    @IBOutlet weak var saveButton: UIButton!
    
    var session: ARSession!
    var configuration = ARWorldTrackingConfiguration()
    var saveData = false
    var jsonObject = [String:Any]()
    
    // intrinsic parameters
    var camWidth: Float?
    var camHeight: Float?
    var camOx: Float?
    var camOy: Float?
    var camFx: Float?
    var camFy: Float?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set this view controller as the session's delegate.
        session = ARSession()
        session.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Enable the smoothed scene depth frame-semantic.
        configuration.frameSemantics = .smoothedSceneDepth

        // Run the view's session.
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        self.saveData = true
    }
    
    
    /*
     From: https://developer.apple.com/forums/thread/663995
     color image and depth image are already aligned. That means the intrinsics of the Lidar are only scaled in relation to the color camera. As the depth image has a resolution of 584 x 384 (frame.sceneDepth!.depthMap) and the color image 3840 x 2880, you get fxD, fyD, cxD and cyD as follows:

      fxD = 534/3840 * 1598.34
      fyD = 384/2880 * 1598.34
      cxD = 534/3840 * 935.70917
      cyD = 384/2880 * 713.61804

     Before transforming the pointcloud to world coordinates, you have to flip them around the X axis to OpenGL coordinate system.
     
     frame.camera.imageResolution = (1920.0, 1440.0)

     */
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.smoothedSceneDepth?.depthMap
        else { return }
        
        // let camIntrinsicsMartix = frame.capturedDepthData?.cameraCalibrationData?.intrinsicMatrix
        let camIntrinsicsMartix = frame.camera.intrinsics
        //let camImageResolution = frame.capturedDepthData?.cameraCalibrationData?.intrinsicMatrixReferenceDimensions
        let camImageResolution = frame.camera.imageResolution

        self.camFx = camIntrinsicsMartix[0][0]
        self.camFy = camIntrinsicsMartix[1][1]
        self.camOx = camIntrinsicsMartix[0][2] // u0
        self.camOy = camIntrinsicsMartix[1][2] // v0
        self.camWidth = Float(camImageResolution.width)
        self.camHeight = Float(camImageResolution.height)
        
        /*
        if (CVPixelBufferIsPlanar(depthMap)) {
            print("Buffer is planar")
        }
         */
        
        let depthMapHeight = CVPixelBufferGetHeight(depthMap)
        let depthMapWidth = CVPixelBufferGetWidth(depthMap)
        
        //print("depthmap w/h: ", w, h)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        //print("w,h, bytesPerRow:", h, w, bytesPerRow) // 192, 256
        
        /*
        let f = CVPixelBufferGetPixelFormatType(depthMap)
        switch f {
        case kCVPixelFormatType_DepthFloat32:
            print("format: kCVPixelFormatType_DepthFloat32")
        case kCVPixelFormatType_OneComponent8:
            print("format: kCVPixelFormatType_OneComponent8")
        default:
            print("format: unknown")
        }
        */
        
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)
        // it should be kCVPixelFormatType_DepthFloat32
        // Arbitrary values of x and y to sample
        let depthMapX = depthMapWidth/2; // must be lower that cols
        let depthMapY = depthMapHeight/2; // must be lower than rows
        
        let baseAddressIndex = depthMapY  * depthMapWidth + depthMapX;
        let pixelValue = floatBuffer[baseAddressIndex];
        CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        
        // print("Pixel @ \(u),\(v): \(pixel)")
        
        // Da die DepthMap eine Größe von 256 * 192 (w * h) und die cam 1920 x 1440 entspricht die die Position des
        // Tiefenwerts an der Stelle (u,v) in der DepthMap der Postion u / w * camWidth, v / h * camHeight der cam

        let camX = Float(depthMapX) / Float(depthMapWidth) * camWidth!
        let camY = Float(depthMapY) / Float(depthMapHeight) * camHeight!
        
        // Calculate X/Y/Z
        let worldZ = pixelValue;
        let worldX = (camX - camOx!) * worldZ / camFx!
        let worldY = (camY - camOy!) * worldZ / camFy!
        //let worldX = (20 * camWidth! - camOx!) * worldZ / camFx!
        //let worldY = (30 * camHeight! - camOy!) * worldZ / camFy!
        
        let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? UIInterfaceOrientation.unknown
        /*
        if (interfaceOrientation.isPortrait) {
            print("Portrait")
        }
        if (interfaceOrientation.isLandscape) {
            print("Landscape")
        }
         */
        
        let viewPort = imageView.bounds
        let viewPortSize = imageView.bounds.size
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)

        // print("viewPortSize:",viewPortSize)
        
        depthMap.sinus(withMaxDepth: 2, andFrequence: 3000)

        let depthBuffer = CIImage(cvPixelBuffer: depthMap)
        
        
        // 1) Convert to "normalized image coordinates"
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/depthMapSize.width, y: 1.0/depthMapSize.height)

        // 2) Flip the Y axis (for some mysterious reason this is only necessary in portrait mode)
        let flipTransform = (interfaceOrientation.isPortrait) ? CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity

        // 3) Apply the transformation provided by ARFrame
        // This transformation converts:
        // - From Normalized image coordinates (Normalized image coordinates range from (0,0) in the upper left corner of the image to (1,1) in the lower right corner)
        // - To view coordinates ("a coordinate space appropriate for rendering the camera image onscreen")
        // See also: https://developer.apple.com/documentation/arkit/arframe/2923543-displaytransform

        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewPortSize)

        // 4) Convert to view size
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)

        // Transform the image and crop it to the viewport
        let transformedImage = depthBuffer.transformed(by: normalizeTransform.concatenating(flipTransform).concatenating(displayTransform).concatenating(toViewPortTransform)).cropped(to: viewPort)
        
        
        let displayImage = UIImage(ciImage: transformedImage)

        DispatchQueue.main.async {
            self.imageView.image = displayImage
        }

        print("X = \(worldX) cm, Y = \(worldY) cm, Z = \(worldZ) cm")
        
        
        if self.saveData {
            print("File schreiben!")
            
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            var pathURL = URL(string: path[0])!
            pathURL.appendPathComponent("test.json")
            let pathString = pathURL.absoluteString
            
            print("path + filename: ",pathString)
            
            do {
                try "bla bla".write(toFile: pathString, atomically: true, encoding: .utf8)
            } catch {
                print("Error", error)
            }
            
            print("Save successful!")
            
            self.saveData = false
        }
    }
    
    
    func currentFrameInfoToDict(currentFrame: ARFrame) -> [String: Any] {
        
        //let currentTime:String = String(format:"%f", currentFrame.timestamp)
        let jsonObject: [String: Any] = [
            "timeStamp": currentFrame.timestamp,
            "cameraPos": dictFromVector3(positionFromTransform(currentFrame.camera.transform)),
            "cameraEulerAngle": dictFromVector3(currentFrame.camera.eulerAngles),
            "cameraTransform": arrayFromTransform(currentFrame.camera.transform),
            "cameraIntrinsics": arrayFromTransform(currentFrame.camera.intrinsics),
            "camImageResolution": [
                "width": currentFrame.camera.imageResolution.width,
                "height": currentFrame.camera.imageResolution.height
            ],
            "depthMapResolution" : [
                "width": CVPixelBufferGetWidth(currentFrame.sceneDepth!.depthMap),
                "height": CVPixelBufferGetHeight(currentFrame.sceneDepth!.depthMap)
            ],
        ]
        
        return jsonObject
    }

}


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
                if pixel > maxDepth {  // cliping ab maxDepth
                    pixel = 0
                } else {
                    pixel /= 2.0  // Normalisieren auf Werte zw. 0-1
                }
                
                pixel = min(1.0, max(pixel, 0.0)) // Wertebereich (0-1) sicherstellen
                floatBuffer[y * width + x] = sin(pixel*frequence)+1.0/2.0 // sinus mit hoher frequenz und transponiert in den Wertebereich von 0-1
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
}
