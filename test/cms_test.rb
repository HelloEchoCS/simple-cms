ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document('history.txt')
    create_document('about.md')
    create_document('changes.txt')

    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal true, last_response.body.include?('history.txt')
    assert_equal true, last_response.body.include?('about.md')
    assert_equal true, last_response.body.include?('changes.txt')
    assert_includes last_response.body, 'Edit'
  end

  def test_open_txt_files
    create_document('history.txt', '1993 - Yukihiro Matsumoto dreams up Ruby.')

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal true, last_response.body.include?('1993 - Yukihiro Matsumoto dreams up Ruby.')
  end

  def test_open_md_files
    create_document('about.md', '## About')

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>About</h2>'
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

  def test_edit_page
    create_document('test.md', '## Before the test')

    get '/test.md/edit'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '## Before the test'
    assert_includes last_response.body, 'type="submit"'
  end

  def test_update_file
    create_document('test.md', '## Before the test')

    post '/test.md', content: "After the test"
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test.md'
    assert_includes last_response.body, 'test.md has been updated.'

    get '/'
    refute_includes last_response.body, 'test.md has been updated.'

    get '/test.md'
    assert_includes last_response.body, 'After the test'
  end

  def test_new_document_page
    get '/new'
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
  end

  def test_create_new_file
    post '/new', file_name: "test_file.md"
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'test_file.md was created.'
    assert_includes last_response.body, 'test_file.md</a>'
  end

  def test_create_file_with_empty_name
    post '/new', file_name: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_delete_file
    create_document('history.txt')

    post '/history.txt/delete'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'history.txt has been deleted.'
    refute_includes last_response.body, 'history.txt</a>'
  end
end
