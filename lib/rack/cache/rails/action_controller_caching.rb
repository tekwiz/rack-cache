module Rack::Cache
  module Rails
    module Caching
      module ActionController
        def rc_stale?(options = Hash.new)
          rc_fresh_when(options)
          !request.fresh?(response)
        end

        def rc_fresh_when(options = Hash.new)
          options.assert_valid_keys(:etag, :last_modified)
          etag = options[:etag]
          last_modified = options[:last_modified]

          response.etag = etag if etag
          response.last_modified = last_modified if last_modified

          cache_control = ['public']
          if etag.nil? and last_modified.nil?
            cache_control << 'only-cache'
          end
          response.headers["Cache-Control"] = cache_control.join(', ')

          if request.fresh?(response)
            head :not_modified
          end
        end
      end
    end
  end
end

module ActionController
  class Base
    include Rack::Cache::Rails::Caching::ActionController
  end
end