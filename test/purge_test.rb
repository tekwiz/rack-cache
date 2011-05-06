# coding: utf-8
require "#{File.dirname(__FILE__)}/spec_setup"
require 'rack/cache/purge'

describe 'A Rack::Cache::Purge' do
  def mock_request(uri, opts)
    env = Rack::MockRequest.env_for(uri, opts || {})
    Rack::Cache::Request.new(env)
  end

  def mock_response(status, headers, body)
    headers ||= {}
    body = Array(body).compact
    Rack::Cache::Response.new(status, headers, body)
  end

  before do
    @request = mock_request('/', {})
    @response = mock_response(200, {}, ['hello world'])

    @storage = Rack::Cache::Storage.instance
    @metastore = @storage.resolve_metastore_uri('heap:/')
    @entitystore = @storage.resolve_entitystore_uri('heap:/')
  end

  it 'deletes stored entries with #purge' do
    key = Rack::Cache::Key.call(@request)
    @metastore.store(@request, @response, @entitystore)
    resp = @metastore.lookup(@request, @entitystore)
    digest = resp.headers['X-Content-Digest']

    @metastore.read(key).should.not.be.nil
    @entitystore.read(digest).should.not.be.nil

    Rack::Cache::Purge.purge(key.to_s)

    @metastore.read(key).should.be.empty
    @entitystore.read(digest).should.be.nil
  end
end