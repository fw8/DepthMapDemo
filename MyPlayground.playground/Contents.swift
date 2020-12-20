//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport

class MyViewController : UIViewController {
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white

        let img = CGImage(width: 256, height: 192, bitsPerComponent: 32, bitsPerPixel: 32, bytesPerRow: 256*4, space: .Float32, bitmapInfo: <#T##CGBitmapInfo#>, provider: <#T##CGDataProvider#>, decode: <#T##UnsafePointer<CGFloat>?#>, shouldInterpolate: <#T##Bool#>, intent: <#T##CGColorRenderingIntent#>)
        let uiimg = UIImage()
        let label = UILabel()
        label.frame = CGRect(x: 150, y: 200, width: 200, height: 20)
        label.text = "Hello World!"
        label.textColor = .black
        label.backgroundColor = .red
        
        view.addSubview(label)
        self.view = view
    }
}
// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()
