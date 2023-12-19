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
    
    private lazy var grid = GridKernel(context: context)
    private lazy var drawCircles = CirclesKernel(context: context)
    private lazy var graph = GraphKernel(context: context, f: "if(x<0.5){y=x*x*2.0;}else{y=1.0-pow(1.0-x, 2.0)*2.0;}")
    private lazy var graph2 = GraphKernel(context: context, f: "y = smoothstep(0.05, 0.95, x);")
    private lazy var plot = LinePlotKernel(context: context)
    private lazy var field: PlotKernel = FieldKernel(context: context)
    private lazy var arrows: PlotKernel = ArrowsKernel(context: context)
    private lazy var dots = DotsPlotKernel(context: context)

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
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan)))
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
    private lazy var points: [vector_float2] = {
        let ub = 500
        return (0...ub).map { i in
            let range = Float(-4.0)...Float(4.0)
            let length = range.upperBound - range.lowerBound
            var x = (Float(i) / Float(ub)) * length + range.lowerBound
            
            return float2(x, cos(10 * x))
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
            IKey(1.0) { t, _ in
                return (1.0 + (3.0 * t)) * .identity
            }
//            IKey(1.0) { t, start in
//                var matrix = matrix_float3x3(zAngle: Float.pi / 4 * t)
//                matrix[2] = float3(0, 0, 1)
//                return matrix * start!
//            }
//            IKey(1.0) { t, start in
//                var matrix = matrix_float3x3.identity
//                matrix[2] = float3(0.1 * t, 0, 1)
//                return matrix * start!
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

    @objc private func tap() {
        psStep()
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let view = gesture.view!
        let location = gesture.location(in: view)
        let normalizedLocation = CGPoint(
            x: location.x / view.bounds.width,
            y: location.y / view.bounds.height
        )
        t = Float(2 * normalizedLocation.y - 1)
    }

    let range = stride(from: Float(-1.0), to: Float(1.0), by: 0.2)
    private lazy var circlePositions: [vector_float2] = range.reduce([]) { acc, y in
        acc + range.map { x in
            return vector_float2(x, y) + vector_float2(Float.pi, 0)
        }
    }

    private func encodePenudlumPhaseSpace(commandBuffer: MTLCommandBuffer, destinationTexture: MTLTexture) {
        let fTime = Float(time.seconds)

        let matrix = matrix_float3x3.identity * 9.0 // planeTransformTimeline.act(time: time)
        let circles = {
            let mu = Float(0.1)
            let g = Float(9.8)
            let L = Float(2.0)

            for index in self.circlePositions.indices {
                let circlePosition = circlePositions[index]
                let theta = circlePosition.x
                let thetaDot = circlePosition.y
                let thetaDotDot = -mu * thetaDot - (g / L) * sin(theta)
                let deriv = vector_float2(thetaDot, thetaDotDot)
                circlePositions[index] += deriv * 1.0 / 512.0
            }

            return circlePositions.enumerated().map { index, position in
                return vector_float4(position.x, position.y, 0.05, Float(index) / Float(circlePositions.count))
            }
        }()

        grid.time = fTime
        grid.matrix = matrix
        grid(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

        field.time = fTime
        field.matrix = matrix
        field(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

        drawCircles.time = fTime
        drawCircles.matrix = matrix
        drawCircles.circles = circles
        drawCircles(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
    }

    private lazy var rodTemperatures: [vector_float2] = {
        let midTemp: Float = 0.5
        return stride(from: Float(0), through: Float(1.0), by: 0.01).map { x in
            return vector_float2(x, x)
            if x >= 0.5 {
                return vector_float2(x, 0.1)
            } else {
                return vector_float2(x, 0.9)
            }
//            let temperature = midTemp + Float.random(in: -1...2) * 0.5
//            return vector_float2(x, temperature)
        }
    }()

    private func encodeRodTemperature(commandBuffer: MTLCommandBuffer, destinationTexture: MTLTexture) {
        var matrix = matrix_float3x3.identity
        matrix *= 0.75
        matrix[2][0] = 0.5
        matrix[2][1] = 0.5
        let fTime = Float(time.seconds)
        let dt: Float = 1.0 / 2.0

        let circles = {
            let alpha = Float(2)
            let indices = rodTemperatures.indices
            for index in indices {
                let T = rodTemperatures[index].y
                let lT = indices.contains(index - 1) ? rodTemperatures[index - 1].y : T
                let rT = indices.contains(index + 1) ? rodTemperatures[index + 1].y : T

                let deriv = alpha * ((lT + rT) / 2 - T)
                rodTemperatures[index].y += deriv * dt
            }
            return rodTemperatures.map { (temp) in
                return vector_float4(temp.x, temp.y, 0.005, 0.0)
            }
        }()

        grid.time = fTime
        grid.matrix = matrix
        grid(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

        drawCircles.time = fTime
        drawCircles.matrix = matrix
        drawCircles.circles = circles
        drawCircles(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
    }

    var ps = ViewController.points()

    static func points() -> [vector_float2] {
        let verticesCount = 8
        let angle = Float.pi * 2 / Float(verticesCount)
        let initialPoint = vector_float2(0, 1)

        var points = [initialPoint]
        for i in 1...verticesCount {
            //                let rotation = simd_quatf(
            //                    angle: angle * Float(i),
            //                    axis: vector_float3(0, 0, 1)
            //                )
            let rotation = matrix_float2x2(angle: angle)
            points.append(rotation * points[i - 1])
        }

        return points
    }

    var magn: Float = 0.5
    var isInitial = true
    func psStep() {
        isInitial = false
        ps = kochPoints(t: t)
        let linesCount = ps.count - 1
        let newLinesCount = linesCount * 4
        let newPointsCount = newLinesCount + 1

        var newPoints = [vector_float2]()
        newPoints.reserveCapacity(newPointsCount)
        newPoints.append(ps[0])

        for i in 1..<ps.count {
            let a = ps[i - 1]
            let b = ps[i]

            let dir = normalize(b - a)
            let perpendicular = vector_float2(-dir.y, dir.x)
            let newLine = [
                mix(a, b, t: 1.0/3.0),
                mix(a, b, t: 1.0 / 2.0) - perpendicular * magn,
                mix(a, b, t: 2.0 / 3.0),
                b
            ]

            newPoints.append(contentsOf: newLine)
        }

        magn *= 1.0 / 3.0
        ps = newPoints
    }

    var t: Float = 1.0
    func kochPoints(t: Float) -> [vector_float2] {
        guard isInitial == false else {
            return ps
        }
        var output = ps

        for i in stride(from: 0, to: ps.count - 1, by: 4) {
            let a = output[i]
            let b = output[i + 4]

            output[i + 2] = mix(mix(a, b, t: 1.0 / 2.0), output[i + 2], t: t)
        }

        return output
    }

    lazy var bezierPlot = BezierPlotKernel(context: context)
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
        let mousePosition = mousePosition

//         pendulum phase space
//        encodePenudlumPhaseSpace(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

//        encodeRodTemperature(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

//        graph.color = vector_float4(x: 1.0, y: 0, z: 0, w: 1.0)
//        graph.time = fTime
//        graph.matrix = matrix
//        graph(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
//        
//        graph2.color = vector_float4(x: 0, y: 1.0, z: 0, w: 1.0)
//        graph2.time = fTime
//        graph2.matrix = matrix
//        graph2(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
        
//        let space = linspace(-4, 4, 100)
//        plot.time = fTime
//        plot.matrix = matrix
//
//        let coss = space.map { float2($0, cos($0)) }
//        let sins = space.map { float2($0, sin(2.0 * $0)) }
//

//        dot.points = (0..<20).map { x in
//            let x = Float(x - 10) / 10
//            return simd_float2(x: x, y: sin( 10 * x))
//        }
//        bezierPlot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)

        let s = simd_float2.zero
        let m = simd_float2(0.6, 0.7)
        let e = simd_float2(1.0, 0.25)

        let steps = 8
        commandBuffer.clear(texture: destinationTexture)

        let points = kochPoints(t: t)
        let matrix = matrix_float3x3(diagonal: .init(2.0))
        if isInitial {
            plot.points = points
            plot.matrix = matrix
            plot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
        } else {
            bezierPlot.points = points
            bezierPlot.matrix = matrix
            bezierPlot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
        }


//        plot.color = float4(1.0, 1.0, 0, 1.0)
//        plot.points = points
//        plot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
//
//        plot.color = float4(0, 1.0, 0, 1.0)
//        plot.points = coss
//        plot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
//
//        plot.color = float4(0, 0.0, 1.0, 1.0)
//        plot.points = zip(sins, coss).map { s, c in float2(s.x, simd_mix(s.y, c.y, 0.5)) }
//        plot(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
        
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

func linspace(_ lowerBound: Float, _ upperBound: Float, _ count: Int = 10) -> [Float] {
    guard count != 1 else {
        return [lowerBound]
    }
    let length = upperBound - lowerBound
    let step = length / Float(count - 1)
    return (0..<count).map { i in
        return lowerBound + Float(i) * step
    }
}
