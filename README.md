# LibmemcachedStore

An ActiveSupport cache store that uses the C-based libmemcached client through Evan Weaver's Ruby/SWIG wrapper, [memcached](https://github.com/evan/memcached). libmemcached is fast (fastest memcache client for Ruby), lightweight, and supports consistent hashing, non-blocking IO, and graceful server failover.

This cache is designed for Rails 3.2+ applications.

## Prerequisites

You'll need the memcached gem installed:

```ruby
gem install memcached
```

or in your Gemfile

```ruby
gem 'memcached'
```

There are no other dependencies.

## Installation

Just add to your Gemfile

```ruby
gem 'libmemcached_store', '~> 0.7.1'
```

and you're set.

## Usage

This is a drop-in replacement for the memcache store that ships with Rails. To
enable, set the `config.cache_store` option to `libmemcached_store`
in the config for your environment

```ruby
config.cache_store = :libmemcached_store
```

If no servers are specified, localhost is assumed. You can specify a list of
server addresses, either as hostnames or IP addresses, with or without a port
designation. If no port is given, 11211 is assumed:

```ruby
config.cache_store = :libmemcached_store, %w(cache-01 cache-02 127.0.0.1:11212)
```

Standard Rails cache store options can be used

```ruby
config.cache_store = :libmemcached_store, '127.0.0.1:11211', {:compress => true, :expires_in => 3600}
```

More advanced options can be passed directly to the client

```ruby
config.cache_store = :libmemcached_store, '127.0.0.1:11211', {:client => { :binary_protocol => true, :no_block => true }}
```

You can also use `:libmemcached_store` to store your application sessions

```ruby
require 'action_dispatch/session/libmemcached_store'
config.session_store :libmemcached_store, :namespace => '_session', :expire_after => 1800
```

## Performance

Used with Rails, __libmemcached_store__ is at least 1.5x faster than __dalli__. See [BENCHMARKS](https://github.com/ccocchi/libmemcached_store/blob/master/BENCHMARKS)
for details

## Props

Thanks to Brian Aker ([http://tangent.org](http://tangent.org)) for creating libmemcached, and Evan
Weaver ([http://blog.evanweaver.com](http://blog.evanweaver.com)) for the Ruby wrapper.
