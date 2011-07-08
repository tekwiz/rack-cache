module Rack::Cache
  # The abstract Observer class for Rack::Cache.  All observers for Rack::Cache
  # must inherit from this class.
  class Observer
    attr_reader :env, :request

    def initialize(env, request)
      @env = env
      @request = request
    end

    # Run after the request is received by Rack::Cache.
    # 
    # Example: Use the X-Forwarded-Host in the cache key for subdomains.
    #
    #     class CacheKeyObserver < Rack::Cache::Observer
    #       def on_request
    #         request.env['rack-cache.cache_key'] = Proc.new { |request|
    #             request.env['HTTP_X_FORWARDED_HOST']+'/'+request.env['REQUEST_URI']
    #           }
    #       end
    #     end
    def on_request
    end

    # Run before the request is forwarded up the chain.
    def before_forward
    end

    # Run after the response is received back from up the chain.
    #
    # Example: Prevent any caching.
    #
    #     class NoCacheObserver < Rack::Cache::Observer
    #       def after_forward(response)
    #         response.instance_exec { def cacheable?() false; end }
    #       end
    #     end
    def after_forward(response)
    end

    # Run when the response is found in the cache.
    def on_hit(response)
    end
  end
end
