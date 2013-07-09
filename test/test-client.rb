# -*- coding: utf-8 -*-
#
# Copyright (C) 2013  Haruka Yoshihara <yoshihara@clear-code.com>
# Copyright (C) 2013  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "socket"
require "groonga/client"

class TestClient < Test::Unit::TestCase
  module ClientFixture
    class << self
      def included(base)
        super
        base.class_eval do
          setup :setup_client
          teardown :teardown_client
        end
      end
    end

    def setup_client
      @client = nil
    end

    def teardown_client
      @client.close if @client
    end
  end

  module Utils
    def client
      @client ||= open_client
    end

    def open_client(&block)
      options = {:host => @address, :port => @port, :protocol => @protocol}
      Groonga::Client.open(options, &block)
    end

    def stub_response(body, output_type=:json)
      @response_body = body
      @response_output_type = output_type
    end
  end

  module Assertions
    NORMALIZED_START_TIME   = Time.parse("2013-05-23T16:43:39+09:00").to_i
    NORMALIZED_ELAPSED_TIME = 29
    def normalize_header(header)
      normalized_header = header.dup
      start_time = header[1]
      if start_time.is_a?(Numeric)
        normalized_header[1] = NORMALIZED_START_TIME
      end
      elapsed_time = header[2]
      if elapsed_time.is_a?(Numeric)
        normalized_header[2] = NORMALIZED_ELAPSED_TIME
      end
      normalized_header
    end

    def assert_header(response)
      normalized_header = normalize_header(response.header)
      assert_equal([0, NORMALIZED_START_TIME, NORMALIZED_ELAPSED_TIME],
                   normalized_header)
    end

    def assert_response(expected_body, response)
      if @response_output_type == :none
        expected_header = nil
        actual_header = response.header
      else
        expected_header = [
          0,
          NORMALIZED_START_TIME,
          NORMALIZED_ELAPSED_TIME,
        ]
        actual_header = normalize_header(response.header)
      end
      actual_body = response.body
      actual_body = yield(actual_body) if block_given?
      assert_equal({
                     :header => expected_header,
                     :body   => expected_body,
                   },
                   {
                     :header => actual_header,
                     :body   => actual_body,
                   })
    end
  end

  module OutputTypeTests
    def test_dump
      dumped_commands = "table_create TEST_TABLE TABLE_NO_KEY"
      stub_response(dumped_commands, :none)
      response = client.dump
      assert_response(dumped_commands, response)
    end

    def test_xml
      stub_response(<<-XML, :xml)
<TABLE_LIST>
<HEADER>
<PROPERTY>
<TEXT>id</TEXT>
<TEXT>UInt32</TEXT></PROPERTY>
<PROPERTY>
<TEXT>name</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>path</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>flags</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>domain</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>range</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>default_tokenizer</TEXT>
<TEXT>ShortText</TEXT></PROPERTY>
<PROPERTY>
<TEXT>normalizer</TEXT>
<TEXT>ShortText</TEXT></PROPERTY></HEADER>
<TABLE>
<INT>256</INT>
<TEXT>Users</TEXT>
<TEXT>/tmp/db/db.0000100</TEXT>
<TEXT>TABLE_HASH_KEY|PERSISTENT</TEXT>
<NULL/>
<NULL/>
<NULL/>
<NULL/></TABLE></TABLE_LIST>
      XML
      response = client.table_list(:output_type => :xml)
      expected_body = [
        table(256,
              "Users",
              "/tmp/db/db.0000100",
              "TABLE_HASH_KEY|PERSISTENT",
              nil,
              nil,
              nil,
              nil),
      ]
      assert_response(expected_body, response)
    end

    private
    def table(id, name, path, flags, domain, range, default_tokenizer,
              normalizer)
      Groonga::Client::Response::TableList::Table.new(id,
                                                      name,
                                                      path,
                                                      flags,
                                                      domain,
                                                      range,
                                                      default_tokenizer,
                                                      normalizer)
    end
  end

  module ColumnsTests
    def test_not_exist
      stub_response('{"key":"value"}')
      response = client.status
      assert_response({"key" => "value"}, response)
    end

    def disabled_test_exist
      stub_response(<<-JSON)
[[["name","ShortText"],
["age","UInt32"]],
["Alice",32],
["Bob",21]]
JSON
      expected_table_infos = [
        {:name => "Alice", :age => 32},
        {:name => "Bob", :age => 21}
      ]
      response = client.table_list
      assert_response(expected_table_infos, response) do |actual_body|
        actual_body.collect do |value|
          value.table_info
        end
      end
    end
  end

  module ParametersTests
    def test_integer
      stub_response("100")
      response = client.cache_limit(:max => 4)
      assert_response(100, response)
    end
  end

  module OpenTests
    def test_return_value
      response = open_client do |client|
        "response"
      end
      assert_equal("response", response)
    end
  end

  module Tests
    include Utils
    include Assertions

    include OutputTypeTests
    include ColumnsTests
    include ParametersTests
    include OpenTests
  end

  class TestGQTP < self
    include Tests
    include ClientFixture

    def setup
      @address = "127.0.0.1"
      @server = TCPServer.new(@address, 0)
      @port = @server.addr[1]
      @protocol = :gqtp

      @response_body = nil
      @thread = Thread.new do
        client = @server.accept
        @server.close

        header = GQTP::Header.parse(client.read(GQTP::Header.size))
        client.read(header.size)

        response_header = GQTP::Header.new
        response_header.size = @response_body.bytesize

        client.write(response_header.pack)
        client.write(@response_body)
        client.close
      end
    end

    def teardown
      @thread.kill
    end
  end

  class TestHTTP < self
    include Tests
    include ClientFixture

    def setup
      @address = "127.0.0.1"
      @server = TCPServer.new(@address, 0)
      @port = @server.addr[1]
      @protocol = :http

      @response_body = nil
      @thread = Thread.new do
        client = @server.accept
        @server.close
        status = 0
        start = Time.now.to_f
        elapsed = rand
        case @response_output_type
        when :json
          header = "[#{status},#{start},#{elapsed}]"
          body = "[#{header},#{@response_body}]"
        when :xml
          body = <<-XML
<RESULT CODE="#{status}" UP="#{start}" ELAPSED="#{elapsed}">
#{@response_body}
</RESULT>
          XML
        else
          body = @response_body
        end
        header = <<-EOH
HTTP/1.1 200 OK
Connection: close
Content-Type: application/json
Content-Length: #{body.bytesize}

EOH
        client.write(header)
        client.write(body)
        client.close
      end
    end
  end
end
