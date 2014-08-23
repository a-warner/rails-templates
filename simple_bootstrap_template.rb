ruby_version = `rvm current`.sub("\n",'')
run "rvm gemset create #{app_name}"
gemset = "#{ruby_version}@#{app_name}"

class_eval do
  define_method(:with_rvm) { |cmd| run "rvm #{gemset} do #{cmd}" }
end

def new_file(name, content)
  create_file name, content, :verbose => false
end

run "rm Gemfile"
new_file "Gemfile", <<-GEMFILE
ruby '#{RbConfig::CONFIG['RUBY_PROGRAM_VERSION']}'
source 'https://rubygems.org'

gem "decent_exposure"
gem "decent_generators"
gem "haml"
gem "haml-rails"
gem "pg"
gem "pry"
gem "pry-rails"
gem "twitter-bootstrap-rails"
gem 'coffee-rails'
gem 'jbuilder', '~> 1.2'
gem 'jquery-rails'
gem 'rails', '~> #{`rails -v`.split(' ').last}'
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
end

run 'rm app/views/layouts/application.html.erb'
new_file 'app/views/layouts/application.html.haml', File.read(File.expand_path('../application_layout.html.haml', __FILE__))

run 'rm public/index.html'
route "root to: 'static#index'"

new_file 'app/views/static/index.html.haml', <<-INDEX
%h1 Hello, #{app_name}!
INDEX

new_file 'app/assets/stylesheets/global.sass', <<-GLOBAL_SASS
body
  padding-top: 70px
GLOBAL_SASS

run "rm README.rdoc"
new_file 'README.md', <<-README
### #{app_name}
README

git :init
git :add => '.'
git :commit => "-m 'Application generated by #{File.basename(__FILE__)}'"
