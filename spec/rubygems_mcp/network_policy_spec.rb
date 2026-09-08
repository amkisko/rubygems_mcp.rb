# frozen_string_literal: true

RSpec.describe RubygemsMcp::NetworkPolicy do
  def public_addrinfo
    instance_double(Addrinfo, ip_address: "93.184.216.34")
  end

  it "refuses http before DNS" do
    expect(Addrinfo).not_to receive(:getaddrinfo)

    expect {
      described_class.validate!("http://github.com/rails/rails")
    }.to raise_error(RubygemsMcp::ValidationError, "URL destination is not allowed")
  end

  it "rejects a host that is not on the allowlist before DNS" do
    expect(Addrinfo).not_to receive(:getaddrinfo)

    expect {
      described_class.validate!("https://example.com/changelog")
    }.to raise_error(RubygemsMcp::ValidationError, "URL destination is not allowed")
  end

  it "rejects userinfo before DNS" do
    expect(Addrinfo).not_to receive(:getaddrinfo)

    expect {
      described_class.validate!("https://user:password@github.com/rails/rails")
    }.to raise_error(RubygemsMcp::ValidationError, "URL destination is not allowed")
  end

  it "resolves an allowlisted host after the host check" do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([public_addrinfo])

    uri, ip_address = described_class.validate!("https://github.com/rails/rails")
    expect(uri.host).to eq("github.com")
    expect(ip_address).to eq("93.184.216.34")
  end

  it "uses host_suffixes to restrict an otherwise allowlisted host" do
    expect(Addrinfo).not_to receive(:getaddrinfo)

    expect {
      described_class.validate!("https://github.com/ruby/ruby", host_suffixes: %w[ruby-lang.org])
    }.to raise_error(RubygemsMcp::ValidationError, "URL destination is not allowed")
  end

  it "accepts a host that matches the override suffixes" do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([public_addrinfo])

    uri, = described_class.validate!(
      "https://www.ruby-lang.org/en/news/",
      host_suffixes: %w[ruby-lang.org]
    )
    expect(uri.host).to eq("www.ruby-lang.org")
  end
end
