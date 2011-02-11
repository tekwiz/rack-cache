module Rack::Cache
  class Purge
    def self.purge(uri, path=false, query=false)
      key = Key.new(uri)
      storage.metastores.values.each do |store|
        store.purge(key.to_s, path, query)
      end

      storage.entitystores.values.each do |store|
        store.purge(key.to_s, path, query)
      end
    end

    protected

    def self.storage
      Rack::Cache::Storage.instance
    end
  end
end