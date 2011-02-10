module Rack::Cache
  class Purge
    def purge(uri, path=false, query=false)
      key = Key.new(uri)
      storage.metastores.each do |store|
        store.purge(key, path, query)
      end

      storage.entitystores.each do |store|
        store.purge(key, path, query)
      end
    end

    protected

    def storage
      Rack::Cache::Storage.instance
    end
    
    def key_for(uri)
      Rack::Cache::Key.call(Rack::Cache::Request.new(env_for(uri)))
    end
  end
end