## Description

NewRelic instrumentation for [riak-ruby-client](https://github.com/basho/riak-ruby-client).

## Dependencies
`newrelic-riak` requires:
- Ruby 1.9.3 or later
- [newrelic](https://github.com/newrelic/rpm)
- [riak-ruby-client](https://github.com/basho/riak-ruby-client)

## Installation

Add the gem file reference to the Gemfile:

```ruby
gem 'newrelic_riak', '~> 0.2.0'
```

As of this writing, this will need to be done with a URL to Gemfury private gem hosting.

## Usage
Just require the gem where you need it:
```ruby
require 'newrelic_riak'
```

