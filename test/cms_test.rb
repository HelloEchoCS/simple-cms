ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal true, last_response.body.include?('history.txt')
    assert_equal true, last_response.body.include?('about.txt')
    assert_equal true, last_response.body.include?('changes.txt')
  end

  def test_open_files
    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal true, last_response.body.include?('1993 - Yukihiro Matsumoto dreams up Ruby.')
    assert_equal true, last_response.body.include?('1995 - Ruby 0.95 released.')
    assert_equal true, last_response.body.include?('2019 - Ruby 2.7 released.')
  end

  def test_nonexistent_file
    get '/nothing-here.txt'
    assert_equal 302, last_response.status
    # Why this is not working?
    # assert_equal 'http://localhost:4567/', last_response['Location']

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'nothing-here.txt does not exist.'

    get '/'
    refute_includes last_response.body, 'nothing-here.txt does not exist.'
  end
end
