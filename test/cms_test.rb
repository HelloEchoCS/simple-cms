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

  def session
    last_request.env["rack.session"]
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
    assert_equal 'nothing-here.txt does not exist.', session[:error]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_nil session[:error]
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
    assert_equal 'test.md has been updated.', session[:success]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test.md'
    assert_nil session[:success]

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
    assert_equal 'test_file.md was created.', session[:success]

    get last_response['Location']
    assert_nil session[:success]
    assert_includes last_response.body, 'test_file.md</a>'
  end

  def test_create_file_with_empty_name
    post '/new', file_name: ""
    assert_equal 422, last_response.status
    assert_nil session[:error]
    assert_includes last_response.body, 'A name is required.'
  end

  def test_delete_file
    create_document('history.txt')

    post '/history.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'history.txt has been deleted.', session[:success]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_nil session[:success]
    refute_includes last_response.body, 'history.txt</a>'
  end

  def test_sign_in_page
    get '/sign_in'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:</lable>'
    assert_includes last_response.body, '<input type="text"'
    assert_includes last_response.body, '<input type="password"'
    assert_includes last_response.body, 'Password:</lable>'
    assert_includes last_response.body, 'Sign In</button>'
  end

  def test_successful_sign_in
    post '/sign_in', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:success]
    assert_equal 'admin', session[:user]
    assert_equal true, session[:signed_in]

    get last_response['Location']
    assert_equal 200, last_response.status

    get '/'
    assert_includes last_response.body, 'Signed in as admin'
    assert_includes last_response.body, 'Sign Out</button>'
  end

  def test_wrong_credentials
    post '/sign_in', username: 'wrongusername', password: 'wrongpassword'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_includes last_response.body, 'value="wrongusername">'
  end

  def test_sign_out
    post '/sign_out'
    assert_equal 302, last_response.status
    assert_equal 'You have been signed out.', session[:success]
    assert_nil session[:username]
    assert_equal false, session[:signed_in]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign In</a>'
  end
end
