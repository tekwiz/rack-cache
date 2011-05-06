module Rack::Cache
  class Storage
    attr_reader :metastores, :entitystores
  end
  
  class Purge
    def self.purge(uri)
      key = Rack::Cache::Key.new(uri)

      storage.metastores.values.each do |metastore|
        # Lookup all cached entries for this key
        entries = metastore.read(key.to_s)
        next unless entries

        # Next purge the metastore of all these entries
        metastore.purge(key.to_s)

        # Last purge entity store
        entries.each do |req, res|
          digest = res['X-Content-Digest']
          storage.entitystores.values.each do |entitystore|
            entitystore.purge(digest)
          end
        end
      end
    end

    protected

    def self.storage
      Rack::Cache::Storage.instance
    end
  end
end