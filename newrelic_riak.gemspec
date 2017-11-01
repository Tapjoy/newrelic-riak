Gem::Specification.new do |gem|
  gem.name = 'newrelic_riak'
  gem.version = '0.2.1'
  gem.authors = ['Alin Popa', 'Tapjoy']
  gem.date = '2016-04-04'
  gem.description = 'NewRelic instrumentation for Riak.'
  gem.email = ['alin.popa@gmail.com', 'oss@tapjoy.com']
  gem.homepage = 'https://github.com/tapjoy/newrelic-riak'
  gem.summary = 'NewRelic instrumentation for Riak.'

  gem.add_runtime_dependency(%q<newrelic_rpm>, ['>= 3.15'])

  gem.files = ['README.md', 'lib/newrelic_riak.rb', 'lib/newrelic_riak/riak_client.rb', 'newrelic_riak.gemspec']
  gem.require_paths = ['lib']
end
