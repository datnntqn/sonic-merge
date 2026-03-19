extension SpeechEnhancer {
    public var isLoaded: Bool { _isLoaded }

    public func unload() {
        guard _isLoaded else { return }
        network = nil
        _isLoaded = false
    }

    public var memoryFootprint: Int {
        guard _isLoaded else { return 0 }
        return 0
    }
}
