/// Remembers the most recent lookup, so several islands asking about the same song share one request.
actor Latest<Key: Equatable, Value> {
    private var key: Key?
    private var task: Task<Value, Never>?

    func value(for key: Key, load: @escaping () async -> Value) async -> Value {
        if self.key != key || task == nil {
            self.key = key
            task = Task { await load() }
        }
        return await task!.value
    }
}
