require 'action_controller/base'
require 'action_controller/caching/sweeping'

module Rack::Cache
  module Rails
    module Pages
      def rc_expire_page(options = {})
        children = options.delete(:children)
        variants = options.delete(:variants)

        url = url_for(options)

        Rack::Cache::Purge.purge(url, children, variants)
      end
    end
  end
end

module ActionController
  class Base
    include Rack::Cache::Rails::Pages
  end
  
  class Caching::Sweeper
    include Rack::Cache::Rails::Pages
  end
end