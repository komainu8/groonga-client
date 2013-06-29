require "test/unit/rr"

class TestCommandTableList < Test::Unit::TestCase
  HEADER = [0,1372430096.70991,0.000522851943969727]

  def test_request
    client = Groonga::Client.open
    header = HEADER
    body = [[["id","UInt32"],["name","ShortText"],["path","ShortText"],["flags","ShortText"],["domain","ShortText"],["range","ShortText"],["default_tokenizer","ShortText"],["normalizer","ShortText"]],
      [256,"Test","/tmp/test.db.0000100","TABLE_HASH_KEY|PERSISTENT",nil,nil,nil,nil]]
    response = Groonga::Client::Response::TableList.new(header, body)
    mock(client).execute_command("table_list", {}) do
      response
    end

    assert_equal(header, client.table_list.header)
  end

  def test_response
    client = Groonga::Client.open
    header = HEADER
    body = [[["id","UInt32"],["name","ShortText"],["path","ShortText"],["flags","ShortText"],["domain","ShortText"],["range","ShortText"],["default_tokenizer","ShortText"],["normalizer","ShortText"]],
      [257,"Ages","/tmp/test.db.0000101","TABLE_DAT_KEY|PERSISTENT","UInt32",nil,nil,nil],
      [256,"Lexicon","/tmp/test.db.0000100","TABLE_PAT_KEY|PERSISTENT","ShortText",nil,"TokenBigram","NormalizerAuto"],
      [258,"Logs","/tmp/test.db.0000102","TABLE_NO_KEY|PERSISTENT",nil,nil,nil,nil]]
    response = Groonga::Client::Response::TableList.new(header, body)
    mock(client).execute_command("table_list", {}) do
      response
    end

    table_list = client.table_list
    assert_equal(3, table_list.size)
    table_list.each do |table|
      assert_equal(Groonga::Client::Response::TableList::Table, table.class)
    end

    table = table_list[1]
    assert_equal(256, table.id)
    assert_equal("Lexicon", table.name)
    assert_equal("/tmp/test.db.0000100", table.path)
    assert_equal("TABLE_PAT_KEY|PERSISTENT", table.flags)
    assert_equal("ShortText", table.domain)
    assert_equal(nil, table.range)
    assert_equal("TokenBigram", table.default_tokenizer)
    assert_equal("NormalizerAuto", table.normalizer)
  end
end

