import CoreMedia

class KeysTimeline<State> {
    enum Error: Swift.Error {
        case invalidKeys
    }
    typealias Action = (_ t: Float, _ lastKeyEndState: State?) -> State
    struct Key {
        let range: CMTimeRange
        let action: Action
        
        func act(absoluteTime: CMTime, lastKeyEndState: State?) -> State {
            let relativeTime = absoluteTime - range.start
            let duration = range.duration
            let progress = relativeTime.seconds / duration.seconds
            return action(Float(progress), lastKeyEndState)
        }
    }
    struct IntermediateKey {
        let duration: CMTime
        let action: Action
        
        init(duration: CMTime, action: @escaping Action) {
            self.duration = duration
            self.action = action
        }
        
        init(_ seconds: Double, action: @escaping Action) {
            self.init(duration: .init(seconds: seconds, preferredTimescale: 60), action: action)
        }
        
        init(frames: CMTimeValue, action: @escaping Action) {
            self.init(duration: .init(value: frames, timescale: 60), action: action)
        }
    }
    @resultBuilder
    struct KeysBuilder {
        static func buildBlock(_ components: IntermediateKey...) -> [IntermediateKey] {
            components
        }
    }

    private(set) var keys: [Key]
    private var lastStates: [Int: State] = [:]
    private var currendKeyIndex: Int = 0
    
    init(keys: [Key]) throws {
        var previousKeyEndTime = CMTime.zero
        
        for key in keys {
            guard key.range.start == previousKeyEndTime else {
                throw Error.invalidKeys
            }
            previousKeyEndTime = key.range.end
        }
        
        self.keys = keys
    }
    
    convenience init(intermediateKeys: [IntermediateKey]) throws {
        var keys = [Key]()
        for intermediateKey in intermediateKeys {
            let range = CMTimeRange(start: keys.last?.range.end ?? .zero, duration: intermediateKey.duration)
            keys.append(.init(range: range, action: intermediateKey.action))
        }
        try self.init(keys: keys)
    }
    
    convenience init(@KeysBuilder _ builder: () -> [IntermediateKey]) throws {
        try self.init(intermediateKeys: builder())
    }
    
    func act(time: CMTime) -> State {
        guard let keyIndex = keys.firstIndex(where: { $0.range.containsTime(time) }) else {
            return lastStates[keys.count - 1]!
        }
        let previousIndex = keyIndex - 1
        if keyIndex != currendKeyIndex {
            currendKeyIndex = keyIndex
            let previousKey = keys[keyIndex - 1]
            lastStates[keyIndex - 1] = previousKey.act(absoluteTime: time, lastKeyEndState: lastStates[previousIndex - 1])
        }
        let key = keys[keyIndex]

        let output = key.act(absoluteTime: time, lastKeyEndState: lastStates[previousIndex])
        lastStates[keyIndex] = output
        return output
    }
}
