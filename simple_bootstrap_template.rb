ruby_version = `rvm current`.sub("\n",'')
run "rvm gemset create #{app_name}"
gemset = "#{ruby_version}@#{app_name}"
app_port = (rand * 10_000 + 1_000).to_i

class_eval do
  define_method(:with_rvm) { |cmd| run "rvm #{gemset} do #{cmd}" }
end

configure_user_auth = ENV['USER_AUTH']

def new_file(name, content)
  create_file name, content, :verbose => false
end

run "rm Gemfile"
new_file "Gemfile", <<-GEMFILE
ruby '#{RbConfig::CONFIG['RUBY_PROGRAM_VERSION']}'
source 'https://rubygems.org'

gem "decent_exposure"
gem "decent_generators"#{%{\ngem "devise"} if configure_user_auth}
gem "haml"
gem "haml-rails"#{%{\ngem "omniauth"} if configure_user_auth}
gem "pg"
gem "pry"
gem "pry-rails"
gem "twitter-bootstrap-rails"
gem 'coffee-rails'
gem 'jbuilder', '~> 1.2'
gem 'jquery-rails'
gem 'rails', '~> #{Rails.version}'
gem 'sass-rails'
gem 'turbolinks'
gem 'uglifier', '>= 1.3.0'

group :test, :development do
  gem "factory_girl"
  gem "fivemat"
  gem "rspec-rails"
  gem "rspec"
end

group :test do
  gem "shoulda-matchers"
end
GEMFILE

with_rvm 'gem install bundler'
with_rvm 'bundle install'
new_file '.ruby-gemset', app_name
new_file '.ruby-version', ruby_version

run "rm config/database.yml"
new_file "config/database.yml", <<-DATABASE_YAML
development:
  adapter: postgresql
  database: #{app_name}-dev
  pool: 10
  timeout: 5000

test:
  adapter: postgresql
  database: #{app_name}-test
  pool: 10
  timeout: 5000
DATABASE_YAML

inside app_name do
  with_rvm 'rails generate bootstrap:install static'
  with_rvm 'rails generate controller static'
  with_rvm 'rails generate rspec:install'
  with_rvm 'rake db:create db:migrate'
  with_rvm 'gem install gem-ctags'
  with_rvm 'gem ctags'

  if configure_user_auth
    with_rvm 'rails generate devise:install'
    with_rvm 'rails generate devise user'
    with_rvm 'rails generate devise:views'
    with_rvm 'rake db:migrate'
  end
end

if configure_user_auth
  insert_into_file "config/environments/development.rb", "  config.action_mailer.default_url_options = { host: '#{app_name}.dev' }\n", :after => "Rails.application.configure do\n"
end

remove_file 'app/views/layouts/application.html.erb'
new_file 'app/views/layouts/application.html.haml', ERB.new(File.read(File.expand_path('../application_layout.html.haml.erb', __FILE__))).result(binding)

remove_file 'app/helpers/application_helper.rb'
new_file 'app/helpers/application_helper.rb', File.read(File.expand_path('../application_helper.rb', __FILE__))

run 'rm public/index.html'
route "root to: 'static#index'"

new_file 'app/views/static/index.html.haml', <<-INDEX
%h1 Hello, #{app_name}!
INDEX

new_file 'app/assets/stylesheets/global.sass', <<-GLOBAL_SASS
body
  padding-top: 70px
GLOBAL_SASS

new_file 'bin/dev', <<-DEV_SERVER
#!/usr/bin/env sh

rails server -p #{app_port}
DEV_SERVER

chmod 'bin/dev', '+x'

run "rm README.rdoc"
new_file 'README.md', <<-README
### #{app_name}
README

new_file '.git/hooks/ctags', File.read(File.expand_path('../ctags', __FILE__))
chmod '.git/hooks/ctags', '+x'

%w(post-checkout post-commit post-merge).each do |git_hook|
  file_path = ".git/hooks/#{git_hook}"
  new_file file_path, <<-HOOK
#!/bin/sh
$GIT_DIR/hooks/ctags >/dev/null 2>&1 &
  HOOK

  chmod file_path, '+x'
end

inside app_name do
  run '.git/hooks/ctags'
end

git :init
git :add => '.'
git :commit => "-m 'Application generated by #{File.basename(__FILE__)}'"
