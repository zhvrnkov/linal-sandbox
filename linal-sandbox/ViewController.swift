import UIKit
import MetalKit
import simd
import CoreMedia
import Accelerate

func sincosf(_ angle: Float) -> (Float, Float) {
    var sa: Float = 0
    var ca: Float = 0
    __sincosf(angle, &sa, &ca)
    return (sa, ca)
}

extension matrix_float2x2 {
    init(angle: Float) {
        self.init(diagonal: .init(repeating: 1.0))
        self[0] = .init(x: cos(angle), y: sin(angle))
        self[1] = .init(x: cos(angle + .pi/2), y: sin(angle + .pi/2))
    }
}

extension matrix_float3x3 {
    static var identity: matrix_float3x3 {
        .init(diagonal: .init(repeating: 1))
    }
    
    init(zAngle: Float) {
        self = .identity
        let (sa, ca) = sincosf(zAngle)
        self[0] = .init(x: ca, y: sa, z: 0)
        self[1] = .init(x: -sa, y: ca, z: 0)
    }
    
    init(xAngle: Float) {
        self = .identity
        let (s, c) = sincosf(xAngle)
        self[1] = .init(x: 0, y: c, z: s)
        self[2] = .init(x: 0, y: -s, z: c) // angle + pi/2
    }
    
    init(yAngle: Float) {
        self = .identity
        let (s, c) = sincosf(yAngle)
        self[0] = .init(x: c, y: 0, z: -s) // angle - pi/2
        self[2] = .init(x: s, y: 0, z: c)
    }
    
    init(ix: vector_float2, iy: vector_float2) {
        self = .identity
        self[0] = .init(ix, 0)
        self[1] = .init(iy, 0)
    }
}

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
    private lazy var circles: [vector_float4] = {
        let radius: Float = 0.05
        let steps = 256
        let angleStep = 2 * Float.pi / Float(steps)
        let step = 1.0 / Float(steps)
        return (0..<steps).map { i in
            let fstep = Float(i)
            let matrix = matrix_float3x3(zAngle: fstep * angleStep)
            var center = vector_float3(x: 1.0, y: 0.0, z: 0.0)
            center = matrix * center
            let circle = vector_float4(x: center.z, y: center.y, z: radius, w: fstep * step)
            return circle
        }
    }()
    private let circleTransformTimeline: KeysTimeline<matrix_float3x3> = {
        typealias IKey = KeysTimeline<matrix_float3x3>.IntermediateKey
        return try! KeysTimeline {
            IKey(1.0) { t, _ in
                let angle = t * Float.pi / 4
                return matrix_float3x3(zAngle: angle)
            }
            IKey(1.0) { t, start in
                let angle = t * Float.pi
                let yAxis = start![1]
                let rot = matrix_float3x3(simd_quatf(angle: angle, axis: float3(0, 1, 0)))
                return start! * rot
            }
            IKey(1.0) { t, start in
                let angle = t * Float.pi
                let rot = matrix_float3x3(simd_quatf(angle: angle, axis: float3(0, 1, 0)))
                return start! * rot
            }
            IKey(1.0) { t, start in
                let iy = float3(0, 1.0 - 2.0 * t, 0)
                var matrix = matrix_float3x3.identity
                matrix[1] = iy
                return start!.inverse * matrix * start! * start!
            }
#warning("how to remove this last key frame?")
            IKey(frames: 1) { _, start in
                return start!
            }
        }
    }()
    private let planeTransformTimeline: KeysTimeline<matrix_float3x3> = {
        typealias IKey = KeysTimeline<matrix_float3x3>.IntermediateKey
        return try! KeysTimeline {
            IKey(5.0) { t, _ in
                return .identity
                var matrix = matrix_float3x3(zAngle: Float.pi / 4 * t)
                matrix[2] = float3(0, 0, 1)
                return matrix.inverse
            }
//            IKey(10.0) { t, start in
//                var matrix = matrix_float3x3(yAngle: Float.pi * t)
//                return start!.inverse * matrix.inverse * start!
//            }
//            IKey(5.0) { t, start in
//
//            }
#warning("how to remove this last key frame?")
            IKey(frames: 1) { _, start in
                return start!
            }
        }
    }()

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
        
        var matrix = planeTransformTimeline.act(time: time)
        let circleMatrix = circleTransformTimeline.act(time: time)
        var circles = {
            let radius: Float = 0.05
            let progress = fTime * 0.1
            var center = vector_float3(x: 1.0, y: 0.0, z: 0.0)
            center = circleMatrix * center
            let circle = vector_float4(x: center.x, y: center.y, z: radius, w: fmodf(progress, 1.0))
            return [circle]
        }()
        
        encoder.set(value: &mousePosition, index: 0)
        encoder.set(value: &fTime, index: 1)
        encoder.set(array: &circles, pointerIndex: 2, countIndex: 3)
        encoder.set(value: &matrix, index: 4)
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
