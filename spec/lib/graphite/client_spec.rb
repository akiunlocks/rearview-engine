require 'spec_helper'

describe Graphite::Client do
  context '.initialize' do
    let(:default_client) { Graphite::Client.new }
    context 'ca_file' do
      it 'uses the cacerts in graphite lib by default' do
        cacerts = File.expand_path("../../../../lib/graphite/cacerts.pem",__FILE__)
        expect(default_client.connection.ssl.ca_file).to eq(cacerts)
      end
      it 'can be specified' do
        expect(Graphite::Client.new({ssl: {ca_file: "cacerts.pem" }}).connection.ssl.ca_file).to eq("cacerts.pem")
      end
    end
    context 'ssl_verify' do
      it 'is true by default' do
        expect(default_client.connection.ssl.verify).to be_true
      end
      it 'can be specified' do
        expect(Graphite::Client.new({ssl: {verify: false}}).connection.ssl.verify).to be_false
      end
    end
    context 'basic_auth' do
      it 'is not enabled by default' do
        expect(default_client.connection.headers['Authorization']).to be_nil
      end
      it 'can be specified' do
        expect(Graphite::Client.new({basic_auth: {user: "foo", password: "bar"}}).connection.headers['Authorization']).not_to be_nil
      end
    end
  end
  context '#find_metric' do
    before do
      @client = Graphite::Client.new(url: 'http://graphite1.graphitehosting.com')
      @connection = mock
      @client.stubs(:connection).returns(@connection)
    end
    it 'makes the correct graphite API query' do
      @connection.expects(:get).with('/metrics/find',{ query: 'stats.my_count' })
      @client.find_metric('stats.my_count')
    end
  end
  context '#render' do
    before do
      @client = Graphite::Client.new(url: 'http://graphite1.graphitehosting.com')
      @connection = mock
      @client.stubs(:connection).returns(@connection)
    end
    it 'makes the correct graphite API query' do
      @connection.expects(:get).with('/render',{ foo: 'bar' })
      @client.render({ foo: 'bar' })
    end
  end
  context '#metric_exists?' do
    before do
      @client = Graphite::Client.new(url: 'http://graphite1.graphitehosting.com')
      @request_stubs = Faraday::Adapter::Test::Stubs.new
      @connection_stub = Faraday.new do |builder|
        builder.adapter :test, @request_stubs
      end
      @client.stubs(:connection).returns(@connection_stub)
    end
    context 'true' do
      it 'when response is 200, content-type is application/json, and json is a non-empty array' do
        @request_stubs.get('/metrics/find?query=stats.my_count') {[ 200, { 'content-type' => 'application/json' }, '[ {"leaf": 1, "context": {}, "text": "my_count", "expandable": 0, "id": "stats.my_count", "allowChildren": 0} ]' ]}
        expect(@client.metric_exists?('stats.my_count')).to be_true
      end
    end
    context 'false' do
      it 'when response is not 200' do
        @request_stubs.get('/metrics/find?query=stats.my_count') {[ 406, { 'content-type' => 'application/json' }, '[ {"leaf": 1, "context": {}, "text": "my_count", "expandable": 0, "id": "stats.my_count", "allowChildren": 0} ]' ]}
        expect(@client.metric_exists?('stats.my_count')).to be_false
      end
      it 'when content-type is not application/json' do
        @request_stubs.get('/metrics/find?query=stats.my_count') {[ 200, { 'content-type' => 'image/png' }, '[ {"leaf": 1, "context": {}, "text": "my_count", "expandable": 0, "id": "stats.my_count", "allowChildren": 0} ]' ]}
        expect(@client.metric_exists?('stats.my_count')).to be_false
      end
      it 'when json is an empty array' do
        @request_stubs.get('/metrics/find?query=stats.my_count') {[ 200, { 'content-type' => 'application/json' }, '[ ]' ]}
        expect(@client.metric_exists?('stats.my_count')).to be_false
      end
    end
  end
  context '#reachable?' do
    before do
      @client = Graphite::Client.new(url: 'http://graphite1.graphitehosting.com')
      @request_stubs = Faraday::Adapter::Test::Stubs.new
      @connection_stub = Faraday.new do |builder|
        builder.adapter :test, @request_stubs
      end
      @client.stubs(:connection).returns(@connection_stub)
    end
    it 'is true when response is 200, content is image/png, and content-length > 0' do
      @request_stubs.get('/render') {[ 200, { 'content-type' => 'image/png', 'content-length' => '123' }, '' ]}
      expect(@client.reachable?).to be_true
    end
    it 'is false when response is not 200' do
      @request_stubs.get('/render') {[ 500, { }, '' ]}
      expect(@client.reachable?).to be_false
    end
    it 'is false when content-type is not image/png' do
      @request_stubs.get('/render') {[ 200, { 'content-type' => 'text/html', 'content-length' => '123' }, '' ]}
      expect(@client.reachable?).to be_false
    end
    it 'is false when content-length is 0' do
      @request_stubs.get('/render') {[ 200, { 'content-type' => 'image/png', 'content-length' => '0' }, '' ]}
      expect(@client.reachable?).to be_false
    end
  end
  context 'forwardable' do
    before do
      @connection_stub = mock
      Faraday.stubs(:new).returns(@connection_stub)
      @client = Graphite::Client.new(url: 'http://graphite1.graphitehosting.com')
    end
    it 'to connection.get' do
      @connection_stub.expects(:get).with('/render')
      @client.get('/render')
    end
    it 'to connection.post' do
      @connection_stub.expects(:post).with('/render')
      @client.post('/render')
    end
  end
end

