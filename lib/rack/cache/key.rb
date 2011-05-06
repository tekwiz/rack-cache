require 'uri'
require 'cgi'
require 'rack/utils'

module Rack::Cache
  class Key
    include Rack::Utils

    # Implement .call, since it seems like the "Rack-y" thing to do. Plus, it
    # opens the door for cache key generators to just be blocks.
    def self.call(request)
      new(request.url).to_s
    end

    def initialize(uri)
      @uri = uri.kind_of?(URI) ? uri : URI.parse(uri)
    end

    # Generate a normalized cache key for the request.
    def to_s
      parts = []
      parts << @uri.scheme << "://"
      parts << @uri.host

      if @uri.scheme == "https" && @uri.port != 443 ||
          @uri.scheme == "http" && @uri.port != 80
        parts << ":" << @uri.port.to_s
      end

      if qs = query_string
        parts << "?"
        parts << qs
      end

      parts.join
    end

    private

    # Build a normalized query string by alphabetizing all keys/values
    # and applying consistent escaping.
    def query_string
      params = CGI.parse(@uri.query || '')
      params = params.keys.sort.map do |key|
        params[key].sort.map do |value|
          "#{escape(key)}=#{escape(value)}"
        end
      end

      params.join('&')
    end
  end
end