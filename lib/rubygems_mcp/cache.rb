# frozen_string_literal: true

module RubygemsMcp
  class Cache
    MAX_ENTRIES = 256

    def initialize(max_entries: MAX_ENTRIES)
      @cache = {}
      @mutex = Mutex.new
      @inflight = {}
      @max_entries = max_entries
    end

    def get(key)
      @mutex.synchronize { read_unlocked(key) }
    end

    def set(key, value, ttl_seconds)
      @mutex.synchronize { write_unlocked(key, value, ttl_seconds) }
    end

    def fetch(key, ttl_seconds)
      cached = get(key)
      return cached unless cached.nil?

      lock = @mutex.synchronize { @inflight[key] ||= Mutex.new }
      lock.synchronize do
        cached = get(key)
        return cached unless cached.nil?

        value = yield
        set(key, value, ttl_seconds)
        value
      ensure
        @mutex.synchronize { @inflight.delete(key) if @inflight[key].equal?(lock) }
      end
    end

    def clear
      @mutex.synchronize do
        @cache.clear
        @inflight.clear
      end
    end

    def size
      @mutex.synchronize { @cache.size }
    end

    private

    def read_unlocked(key)
      entry = @cache[key]
      return nil unless entry

      if entry[:expires_at] < Time.now
        @cache.delete(key)
        return nil
      end

      entry[:value]
    end

    def write_unlocked(key, value, ttl_seconds)
      evict_unlocked if @cache.size >= @max_entries && !@cache.key?(key)
      @cache.delete(key)
      @cache[key] = {value: value, expires_at: Time.now + ttl_seconds}
    end

    def evict_unlocked
      now = Time.now
      @cache.delete_if { |_key, entry| entry[:expires_at] < now }
      @cache.shift while @cache.size >= @max_entries
    end
  end
end
