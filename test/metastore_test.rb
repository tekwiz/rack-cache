require "#{File.dirname(__FILE__)}/spec_setup"

require 'rack/cache/key'
require 'rack/cache/entitystore'
require 'rack/cache/metastore'

describe_shared 'A Rack::Cache::MetaStore Implementation' do
  before do
    @request = mock_request('/', {})
    @response = mock_response(200, {}, ['hello world'])
  end
  
  # Low-level implementation methods ===========================================

  it 'writes a list of negotiation tuples with #write' do
    lambda { @store.write(key('/test'), [[{}, {}]]) }.should.not.raise
  end

#  it 'reads a list of negotiation tuples with #read' do
#    @store.write(key('/test', [[{},{}],[{},{}]])
#    tuples = @store.read(key('/test')
#    tuples.should.equal [ [{},{}], [{},{}] ]
#  end
#
#  it 'reads an empty list with #read when nothing cached at key' do
#    @store.read(key('/nothing').should.be.empty
#  end
#
#  it 'removes entries for key with #purge' do
#    @store.write(key('/test'), [[{},{}]])
#    @store.read(key('/test').should.not.be.empty
#
#    @store.purge('/test')
#    @store.read(key('/test').should.be.empty
#  end
#
#  it 'succeeds when purging non-existing entries' do
#    @store.read(key('/test').should.be.empty
#    @store.purge('/test')
#  end
#
#  it 'returns nil from #purge' do
#    @store.write(key('/test'), [[{},{}]])
#    @store.purge('/test').should.be nil
#    @store.read(key('/test').should.equal []
#  end

  it 'removes child entries for key with #purge' do
    @store.write(key('/test'), [[{},{}]])
    @store.write(key('/test/_a=b'), [[{},{}]])
    @store.write(key('/test/1'), [[{},{}]])
    @store.write(key('/test/1/2'), [[{},{}]])

    @store.read(key('/test')).should.not.be.empty
    @store.read(key('/test/_a=b')).should.not.be.empty
    @store.read(key('/test/1')).should.not.be.empty
    @store.read(key('/test/1/2')).should.not.be.empty

    @store.purge(key('/test'), true)

    @store.read(key('/test')).should.be.empty
    @store.read(key('/test/_a=b')).should.not.be.empty
    @store.read(key('/test/1')).should.be.empty
    @store.read(key('/test/1/2')).should.be.empty
  end

  it 'removes variant entries for key with #purge' do
    @store.write(key('/test'), [[{},{}]])
    @store.write(key('/test/_a=b&c=d'), [[{},{}]])
    @store.write(key('/test/1'), [[{},{}]])

    @store.read(key('/test')).should.not.be.empty
    @store.read(key('/test/_a=b&c=d')).should.not.be.empty
    @store.read(key('/test/1')).should.not.be.empty

    @store.purge(key('/test'), false, true)

    @store.read(key('/test')).should.be.empty
    @store.read(key('/test/_a=b&c=d')).should.be.empty
    @store.read(key('/test/1')).should.not.be.empty
  end

#  %w[/test http/example.com/8080/ /test/x=y /test/x=y&p=q].each do |key|
#    it "can read and write key: '#{key}'" do
#      lambda { @store.write(key), [[{},{}]]) }.should.not.raise
#      @store.read(key).should.equal [[{},{}]]
#    end
#  end
#
#  it "can read and write fairly large keys" do
#    key = "b" * 4096
#    lambda { @store.write(key), [[{},{}]]) }.should.not.raise
#    @store.read(key).should.equal [[{},{}]]
#  end
#
#  it "allows custom cache keys from block" do
#    request = mock_request('/test', {})
#    request.env['rack-cache.cache_key'] =
#      lambda { |request| request.path_info.reverse }
#    @store.cache_key(request).should == 'tset/'
#  end
#
#  it "allows custom cache keys from class" do
#    request = mock_request('/test', {})
#    request.env['rack-cache.cache_key'] = Class.new do
#      def self.call(request); request.path_info.reverse end
#    end
#    @store.cache_key(request).should == 'tset/'
#  end

  # Abstract methods ===========================================================

  # Stores an entry for the given request args, returns a url encoded cache key
  # for the request.
  define_method :store_simple_entry do |*request_args|
    path, headers = request_args
    @request = mock_request(path || '/test', headers || {})
    @response = mock_response(200, {'Cache-Control' => 'max-age=420'}, ['test'])
    body = @response.body
    cache_key = @store.store(@request, @response, @entity_store)
    @response.body.should.not.be body
    cache_key
  end

  it 'stores a cache entry' do
    cache_key = store_simple_entry
    @store.read(cache_key).should.not.be.empty
  end

  it 'sets the X-Content-Digest response header before storing' do
    cache_key = store_simple_entry
    req, res = @store.read(cache_key).first
    res['X-Content-Digest'].should.equal 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3'
  end

  it 'finds a stored entry with #lookup' do
    store_simple_entry
    response = @store.lookup(@request, @entity_store)
    response.should.not.be.nil
    response.should.be.kind_of Rack::Cache::Response
    response.finalize
  end

  it 'does not find an entry with #lookup when none exists' do
    req = mock_request('/test', {'HTTP_FOO' => 'Foo', 'HTTP_BAR' => 'Bar'})
    @store.lookup(req, @entity_store).should.be.nil
  end

  it "canonizes urls for cache keys" do
    store_simple_entry(path='/test?x=y&p=q')

    hits_req = mock_request(path, {})
    miss_req = mock_request('/test?p=x', {})

    response = @store.lookup(hits_req, @entity_store)
    response.should.not.be.nil
    response.finalize

    response = @store.lookup(miss_req, @entity_store)
    response.should.be.nil
  end

  it 'does not find an entry with #lookup when the body does not exist' do
    store_simple_entry
    @response.headers['X-Content-Digest'].should.not.be.nil
    @response.finalize
    @entity_store.purge(@response.headers['X-Content-Digest'])
    @store.lookup(@request, @entity_store).should.be.nil
  end

  it 'restores response headers properly with #lookup' do
    store_simple_entry
    response = @store.lookup(@request, @entity_store)
    response.headers.
      should.equal @response.headers.merge('Content-Length' => '4')
    response.finalize
  end

  it 'restores response body from entity store with #lookup' do
    store_simple_entry
    response = @store.lookup(@request, @entity_store)
    body = '' ; response.body.each {|p| body << p}
    body.should.equal 'test'
    response.finalize
  end

  it 'invalidates meta and entity store entries with #invalidate' do
    store_simple_entry
    @store.invalidate(@request, @entity_store)
    response = @store.lookup(@request, @entity_store)
    response.should.be.kind_of Rack::Cache::Response
    response.should.not.be.fresh
    response.finalize
  end

  it 'succeeds quietly when #invalidate called with no matching entries' do
    req = mock_request('/test', {})
    @store.invalidate(req, @entity_store)
    response = @store.lookup(@request, @entity_store)
    response.should.be.nil
  end

  # Vary =======================================================================

  it 'does not return entries that Vary with #lookup' do
    req1 = mock_request('/test', {'HTTP_FOO' => 'Foo', 'HTTP_BAR' => 'Bar'})
    req2 = mock_request('/test', {'HTTP_FOO' => 'Bling', 'HTTP_BAR' => 'Bam'})
    res = mock_response(200, {'Vary' => 'Foo Bar'}, ['test'])
    @store.store(req1, res, @entity_store)
    res.finalize

    response = @store.lookup(req2, @entity_store)
    response.should.be.nil
  end

  it 'stores multiple responses for each Vary combination' do
    req1 = mock_request('/test', {'HTTP_FOO' => 'Foo',   'HTTP_BAR' => 'Bar'})
    res1 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 1'])
    key = @store.store(req1, res1, @entity_store)
    res1.finalize

    req2 = mock_request('/test', {'HTTP_FOO' => 'Bling', 'HTTP_BAR' => 'Bam'})
    res2 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 2'])
    @store.store(req2, res2, @entity_store)
    res2.finalize

    req3 = mock_request('/test', {'HTTP_FOO' => 'Baz',   'HTTP_BAR' => 'Boom'})
    res3 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 3'])
    @store.store(req3, res3, @entity_store)
    res3.finalize

    response = @store.lookup(req3, @entity_store)
    slurp(response.body).should.equal 'test 3'
    response.finalize

    response = @store.lookup(req1, @entity_store)
    slurp(response.body).should.equal 'test 1'
    response.finalize

    response = @store.lookup(req2, @entity_store)
    slurp(response.body).should.equal 'test 2'
    response.finalize

   @store.read(key).length.should.equal 3
  end

  it 'overwrites non-varying responses with #store' do
    req1 = mock_request('/test', {'HTTP_FOO' => 'Foo',   'HTTP_BAR' => 'Bar'})
    res1 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 1'])
    key = @store.store(req1, res1, @entity_store)
    res1.finalize
    
    res1 = @store.lookup(req1, @entity_store)
    slurp(res1.body).should.equal 'test 1'
    res1.finalize

    req2 = mock_request('/test', {'HTTP_FOO' => 'Bling', 'HTTP_BAR' => 'Bam'})
    res2 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 2'])
    @store.store(req2, res2, @entity_store)
    res2.finalize

    res2 = @store.lookup(req2, @entity_store)
    slurp(res2.body).should.equal 'test 2'
    res2.finalize

    req3 = mock_request('/test', {'HTTP_FOO' => 'Foo',   'HTTP_BAR' => 'Bar'})
    res3 = mock_response(200, {'Vary' => 'Foo Bar'}, ['test 3'])
    @store.store(req3, res3, @entity_store)
    res3.finalize

    res3 = @store.lookup(req3, @entity_store)
    slurp(res3.body).should.equal 'test 3'
    res3.finalize

    @store.read(key).length.should.equal 2
  end

  # Helper Methods =============================================================

  define_method :key do |uri|
    Rack::Cache::Key.new(uri).to_s
  end

  define_method :mock_request do |uri,opts|
    env = Rack::MockRequest.env_for(uri, opts || {})
    Rack::Cache::Request.new(env)
  end

  define_method :mock_response do |status,headers,body|
    headers ||= {}
    body = Array(body).compact
    Rack::Cache::Response.new(status, headers, body)
  end

  define_method :slurp do |body|
    buf = ''
    body.each {|part| buf << part }
    buf
  end
end


describe 'Rack::Cache::MetaStore' do
#  describe 'Heap' do
#    it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
#    before do
#      @store = Rack::Cache::MetaStore::Heap.new
#      @entity_store = Rack::Cache::EntityStore::Heap.new
#    end
#  end
#
#  describe 'Disk' do
#    it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
#
#    before do
#      @temp_dir = create_temp_directory
#      @store = Rack::Cache::MetaStore::Disk.new("#{@temp_dir}/meta")
#      @entity_store = Rack::Cache::EntityStore::Disk.new("#{@temp_dir}/entity")
#    end
#
#    after do
#      @request = nil
#      # Close open file handles so directories can be deleted
#      @response.finalize
#      remove_entry_secure @temp_dir
#    end
#  end

#  need_memcached 'metastore tests' do
#    describe 'MemCached' do
#      it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
#      before :each do
#        $memcached.flush
#        @store = Rack::Cache::MetaStore::MemCached.new($memcached)
#        @entity_store = Rack::Cache::EntityStore::Heap.new
#      end
#    end
#  end
#
#  need_dalli 'metastore tests' do
#    describe 'Dalli' do
#      it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
#      before :each do
#        $dalli.flush_all
#        @store = Rack::Cache::MetaStore::Dalli.new($dalli)
#        @entity_store = Rack::Cache::EntityStore::Heap.new
#      end
#    end
#  end

  need_redis 'metastore tests' do
    describe 'Redis' do
      it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
      before :each do
        @store        = Rack::Cache::Storage.instance.resolve_metastore_uri(ENV['REDIS'])
        @entity_store = Rack::Cache::Storage.instance.resolve_entitystore_uri(ENV['REDIS'])
        @request  = mock_request('/', {})
        @response = mock_response(200, {}, ['hello world'])
      end

      after :each do
        @store.cache.flushall
        @entity_store.cache.flushall
      end
    end
  end

#  need_java 'entity store testing' do
#    module Rack::Cache::AppEngine
#      module MC
#        class << (Service = {})
#
#          def contains(key); include?(key); end
#          def get(key); self[key]; end;
#          def put(key, value, ttl = nil)
#            self[key] = value
#          end
#
#        end
#      end
#    end
#
#    describe 'GAEStore' do
#      it_should_behave_like 'A Rack::Cache::MetaStore Implementation'
#      before :each do
#        Rack::Cache::AppEngine::MC::Service.clear
#        @store = Rack::Cache::MetaStore::GAEStore.new
#        @entity_store = Rack::Cache::EntityStore::Heap.new
#      end
#    end
#  end
end
