# frozen_string_literal: true

module RubygemsMcp
  # Base error class for all RubygemsMcp errors
  class Error < StandardError; end

  # HTTP/API errors
  class APIError < Error
    attr_reader :status_code, :response_data, :uri

    def initialize(message, status_code: nil, response_data: nil, uri: nil)
      super(message)
      @status_code = status_code
      @response_data = response_data
      @uri = uri
    end
  end

  class NotFoundError < APIError; end
  class ServerError < APIError; end
  class ClientError < APIError; end

  # Data validation errors
  class CorruptedDataError < Error
    attr_reader :original_error, :response_size, :uri

    def initialize(message, original_error: nil, response_size: nil, uri: nil)
      super(message)
      @original_error = original_error
      @response_size = response_size
      @uri = uri
    end
  end

  class ResponseSizeExceededError < Error
    attr_reader :size, :max_size, :uri

    def initialize(size, max_size, uri: nil)
      @size = size
      @max_size = max_size
      @uri = uri
      super("Response size (#{size} bytes) exceeds maximum allowed size (#{max_size} bytes). This may indicate crawler protection.")
    end
  end

  # Input validation errors
  class ValidationError < Error; end
end
