# LibmemcachedStore

An ActiveSupport cache store that uses the C-based libmemcached client through Evan Weaver's Ruby/SWIG wrapper, [memcached](https://github.com/evan/memcached). libmemcached is fast (fastest memcache client for Ruby), lightweight, and supports consistent hashing, non-blocking IO, and graceful server failover.

This cache is designed for Rails 3+ applications.

## Prerequisites

You'll need the memcached gem installed:

  gem install memcached

or in your Gemfile  

  gem 'memcached'

There are no other dependencies.

## Usage

This is a drop-in replacement for the memcache store that ships with Rails. To
enable, set the `config.cache_store` option to `:libmemcached_store`
in the config for your environment

  config.cache_store = :libmemcached_store

If no servers are specified, localhost is assumed. You can specify a list of
server addresses, either as hostnames or IP addresses, with or without a port
designation. If no port is given, 11211 is assumed:

  config.cache_store = :libmemcached_store, %w(cache-01 cache-02 127.0.0.1:11212)

Other options are passed directly to the memcached client
  
  config.cache_store = :libmemcached_store, 127.0.0.1:11211, default_ttl: 3600, compress: true

You can also use `:libmemcached_store` to store your application sessions

  config.session_store = :libmemcached_store, namespace: '_session', expire_after: 1800

## Props

Thanks to Brian Aker ([http://tangent.org](http://tangent.org)) for creating libmemcached, and Evan
Weaver ([http://blog.evanweaver.com](http://blog.evanweaver.com)) for the Ruby wrapper.