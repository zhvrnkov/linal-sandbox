//
//  ViewController.swift
//  sdf-example
//
//  Created by Zhavoronkov Vlad on 12/13/22.
//

import UIKit
import MetalKit
import simd
import CoreMedia

class ViewController: UIViewController {
    
    private(set) lazy var pipelineState: MTLComputePipelineState = {
        return try! context.makeComputePipelineState(functionName: "shader")
    }()
    private(set) lazy var context = try! MTLContext()
    private lazy var mtkView: MTKView = {
        let view = MTKView()
        view.clearColor = .init(red: 0, green: 1.0, blue: 0, alpha: 1.0)
        view.device = context.device
        view.delegate = self
        view.framebufferOnly = false
        view.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hover)))
        return view
    }()
    
    private var mousePosition: vector_float2 = .zero
    private var time = CMTime(value: 0, timescale: 60)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mtkView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.safeAreaBounds
        mtkView.frame.origin = bounds.origin
        mtkView.frame.size = bounds.size
    }
    
    @objc private func hover(gesture: UIHoverGestureRecognizer) {
        var location = gesture.location(in: mtkView)
        location.x /= mtkView.bounds.width
        location.y /= mtkView.bounds.height
        mousePosition.x = .init(location.x)
        mousePosition.y = .init(location.y)
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print(#function, size)
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = context.commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable else {
            print(#function, "NO BUFF AND DRAWABLE")
            return
        }
        let destinationTexture = drawable.texture
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        var fTime = Float(time.seconds)
        var mousePosition = mousePosition
        
        encoder.set(value: &mousePosition, index: 0)
        encoder.set(value: &fTime, index: 1)
        encoder.set(textures: [destinationTexture])
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        time.value += 1
    }
}

extension UIEdgeInsets {
    var verticalInsets: CGFloat {
        top + bottom
    }
    
    var horizontalInsets: CGFloat {
        left + right
    }
}

extension UIView {
    var safeAreaBounds: CGRect {
        let origin = CGPoint(x: safeAreaInsets.left, y: safeAreaInsets.top)
        let size = CGSize(width: bounds.width - safeAreaInsets.horizontalInsets,
                          height: bounds.height - safeAreaInsets.verticalInsets)
        return .init(origin: origin, size: size)

    }
}
