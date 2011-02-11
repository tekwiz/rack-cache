require 'uri'
require 'cgi'
require 'rack/utils'

# A cache key is hierarchal, similar to a file system.  This allows multiple keys
# to be cached at once.
#
# For example, imagine you have a book store application that supports the following
# uris and cache keys (where hexdigest is the MD5 hash of the key)
#
#   GET /books
#   Key: /books/_.hex_digest
#
#   GET /books?sort=title
#   Key: /books/_sort=title.hex_digest
#
#   GET /books?sort=author
#   Key: /books/_sort=title.hex_digest
#
#   GET /book/1
#   Key: /books/1/_.hex_digest
#
#   GET /book/2
#   Key: /books/2/_.hex_digest
#
# Now assume the information about books is updated.
#
#   * A book is added.  Uncache any key /books/_*
#   * A book is deleted.  Uncache any key /books/_*
#   * Book 1 is update/deleted.  Uncache any key /books/_* and /books/1/*
#   * Book 3 is update/deleted.  Uncache any key /books/_* and /books/3/*
#




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
      parts << @uri.scheme
      parts << @uri.host

      if @uri.scheme == "https" && @uri.port != 443 ||
          @uri.scheme == "http" && @uri.port != 80
        parts << @uri.port.to_s
      end

      parts << @uri.path
      parts << query_string

      key = parts.compact.join('/').gsub(%r{//}, '/')
      "#{key}.#{hexdigest(key.to_s)}"
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

      "_#{params.join('&')}"
    end

    def hexdigest(data)
      Digest::SHA1.hexdigest(data)
    end
  end
end
