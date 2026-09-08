# frozen_string_literal: true

RSpec.describe RubygemsMcp::Cache do
  it "evicts the oldest entry when the cap is reached" do
    cache = described_class.new(max_entries: 2)
    cache.set("a", 1, 60)
    cache.set("b", 2, 60)
    cache.set("c", 3, 60)

    expect(cache.size).to eq(2)
    expect(cache.get("a")).to be_nil
    expect(cache.get("c")).to eq(3)
  end

  it "treats only nil as a miss" do
    cache = described_class.new
    cache.set("false", false, 60)
    cache.set("empty", "", 60)

    expect(cache.get("false")).to be(false)
    expect(cache.get("empty")).to eq("")
    expect {
      cache.fetch("false", 60) { raise "should not yield" }
    }.not_to raise_error
  end

  it "runs the fetch block once under concurrent callers" do
    cache = described_class.new
    calls = 0
    mutex = Mutex.new

    threads = Array.new(2) do
      Thread.new do # rubocop:disable ThreadSafety/NewThread -- single-flight needs two callers
        cache.fetch("shared", 60) do
          mutex.synchronize { calls += 1 }
          sleep 0.05
          "ok"
        end
      end
    end
    values = threads.map(&:value)

    expect(calls).to eq(1)
    expect(values).to eq(%w[ok ok])
  end
end
