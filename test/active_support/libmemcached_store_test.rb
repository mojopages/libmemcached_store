# encoding: utf-8

require 'test_helper'
require 'memcached'
require 'active_support'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/object/duplicable'
require 'active_support/cache/libmemcached_store'

# Make it easier to get at the underlying cache options during testing.
class ActiveSupport::Cache::LibmemcachedStore
  def client_options
    @cache.options
  end
end

class MockUser
  def cache_key
    'foo'
  end
end

module CacheStoreBehavior
  def test_fetch_without_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:write_entry).never
    assert_equal 'bar', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_cache_miss
    @cache.expects(:write_entry).with('foo', 'baz', nil)
    assert_equal 'baz', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_forced_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:read_entry).never
    @cache.expects(:write_entry).with('foo', 'baz', force: true)
    assert_equal 'baz', @cache.fetch('foo', force: true) { 'baz' }
  end

  def test_fetch_with_cached_false
    @cache.write('foo', false)
    refute @cache.fetch('foo') { raise }
  end

  def test_fetch_with_raw_object
    o = Object.new
    o.instance_variable_set :@foo, 'bar'
    assert_equal o, @cache.fetch('foo', raw: true) { o }
  end

  def test_fetch_with_cache_key
    u = MockUser.new
    @cache.write(u.cache_key, 'bar')
    assert_equal 'bar', @cache.fetch(u) { raise }
  end

  def test_should_read_and_write_strings
    assert @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_should_read_and_write_hash
    assert @cache.write('foo', { a: 'b' })
    assert_equal({ a: 'b' }, @cache.read('foo'))
  end

  def test_should_read_and_write_integer
    assert @cache.write('foo', 1)
    assert_equal 1, @cache.read('foo')
  end

  def test_should_read_and_write_nil
    assert @cache.write('foo', nil)
    assert_equal nil, @cache.read('foo')
  end

  def test_should_read_and_write_false
    assert @cache.write('foo', false)
    assert_equal false, @cache.read('foo')
  end

  def test_read_and_write_compressed_data
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 1)
    assert_equal 'bar', @cache.read('foo')
  end

  def test_write_should_overwrite
    @cache.write('foo', 'bar')
    @cache.write('foo', 'baz')
    assert_equal 'baz', @cache.read('foo')
  end

  def test_write_compressed_data
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 1, :raw => true)
    assert_equal Zlib::Deflate.deflate('bar'), @cache.instance_variable_get(:@cache).get('foo', false)
  end

  def test_read_miss
    assert_nil @cache.read('foo')
  end

  def test_read_should_return_a_different_object_id_each_time_it_is_called
    @cache.write('foo', 'bar')
    refute_equal @cache.read('foo').object_id, @cache.read('foo').object_id
  end

  def test_read_multi
    @cache.write('foo', 'bar')
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_read_multi_with_array
    @cache.write('foo', 'bar')
    @cache.write('fu', 'baz')
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi(['foo', 'fu']))
  end

  def test_read_multi_with_raw
    @cache.write('foo', 'bar', :raw => true)
    @cache.write('fu', 'baz', :raw => true)
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_read_multi_with_compress
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 1)
    @cache.write('fu', 'baz', :compress => true, :compress_threshold => 1)
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_cache_key
    o = MockUser.new
    @cache.write(o, 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_param_as_cache_key
    obj = Object.new
    def obj.to_param
      'foo'
    end
    @cache.write(obj, 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_array_as_cache_key
    @cache.write([:fu, 'foo'], 'bar')
    assert_equal 'bar', @cache.read('fu/foo')
  end

  def test_hash_as_cache_key
    @cache.write({:foo => 1, :fu => 2}, 'bar')
    assert_equal 'bar', @cache.read('foo=1/fu=2')
  end

  def test_keys_are_case_sensitive
    @cache.write('foo', 'bar')
    assert_nil @cache.read('FOO')
  end

  def test_keys_with_spaces
    assert_equal 'baz', @cache.fetch('foo bar') { 'baz' }
  end

  def test_exist
    @cache.write('foo', 'bar')
    assert @cache.exist?('foo')
    refute @cache.exist?('bar')
  end

  def test_delete
    @cache.write('foo', 'bar')
    assert @cache.exist?('foo')
    assert @cache.delete('foo')
    refute @cache.exist?('foo')
  end

  def test_delete_with_unexistent_key
    @cache.expects(:log_error).never
    refute @cache.exist?('foo')
    refute @cache.delete('foo')
  end

  def test_store_objects_should_be_immutable
    @cache.write('foo', 'bar')
    @cache.read('foo').gsub!(/.*/, 'baz')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_original_store_objects_should_not_be_immutable
    bar = 'bar'
    @cache.write('foo', bar)
    assert_equal 'baz', bar.gsub!(/r/, 'z')
  end

  def test_crazy_key_characters
    crazy_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert @cache.write(crazy_key, "1", :raw => true)
    assert_equal "1", @cache.read(crazy_key)
    assert_equal "1", @cache.fetch(crazy_key)
    assert @cache.delete(crazy_key)
    refute @cache.exist?(crazy_key)
    assert_equal "2", @cache.fetch(crazy_key, :raw => true) { "2" }
    assert_equal 3, @cache.increment(crazy_key)
    assert_equal 2, @cache.decrement(crazy_key)
  end

  def test_really_long_keys
    key = "a" * 251
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
    assert_equal "bar", @cache.fetch(key)
    assert_nil @cache.read("#{key}x")
    assert_equal({key => "bar"}, @cache.read_multi(key))
    assert @cache.delete(key)
    refute @cache.exist?(key)
    assert @cache.write(key, '2', :raw => true)
    assert_equal 3, @cache.increment(key)
    assert_equal 2, @cache.decrement(key)
  end

  def test_really_long_keys_with_namespace
    @cache = ActiveSupport::Cache.lookup_store(:libmemcached_store, :expires_in => 60, :namespace => 'namespace')
    test_really_long_keys
  end
end

module CacheIncrementDecrementBehavior
  def test_increment
    @cache.write('foo', '1', :raw => true)
    assert_equal 1, @cache.read('foo').to_i
    assert_equal 2, @cache.increment('foo')
    assert_equal 2, @cache.read('foo').to_i
    assert_equal 3, @cache.increment('foo')
    assert_equal 3, @cache.read('foo').to_i
  end

  def test_decrement
    @cache.write('foo', '3', :raw => true)
    assert_equal 3, @cache.read('foo').to_i
    assert_equal 2, @cache.decrement('foo')
    assert_equal 2, @cache.read('foo').to_i
    assert_equal 1, @cache.decrement('foo')
    assert_equal 1, @cache.read('foo').to_i
  end

  def test_increment_decrement_non_existing_keys
    @cache.expects(:log_error).never
    assert_nil @cache.increment('foo')
    assert_nil @cache.decrement('bar')
  end
end

module CacheCompressBehavior
  def test_read_and_write_compressed_small_data
    @cache.write('foo', 'bar', :compress => true)
    raw_value = @cache.send(:read_entry, 'foo', {}).raw_value
    assert_equal 'bar', @cache.read('foo')
    value = Marshal.load(raw_value) rescue raw_value
    assert_equal 'bar', value
  end

  def test_read_and_write_compressed_large_data
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 2)
    raw_value = @cache.send(:read_entry, 'foo', {}).raw_value
    assert_equal 'bar', @cache.read('foo')
    assert_equal 'bar', Marshal.load(Zlib::Inflate.inflate(raw_value))
  end
end

class LibmemcachedStoreTest < MiniTest::Unit::TestCase
  include CacheStoreBehavior
  include CacheIncrementDecrementBehavior

  def setup
    @cache = ActiveSupport::Cache.lookup_store(:libmemcached_store, expires_in: 60)
    @cache.clear
    @cache.silence!
  end

  def test_should_identify_cache_store
    assert_kind_of ActiveSupport::Cache::LibmemcachedStore, @cache
  end

  def test_should_set_server_addresses_to_nil_if_none_are_given
    assert_equal [], @cache.addresses
  end

  def test_should_set_custom_server_addresses
    store = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost', '192.168.1.1'
    assert_equal %w(localhost 192.168.1.1), store.addresses
  end

  def test_should_enable_consistent_ketema_hashing_by_default
    assert_equal :consistent_ketama, @cache.client_options[:distribution]
  end

  def test_should_not_enable_non_blocking_io_by_default
    assert_equal false, @cache.client_options[:no_block]
  end

  def test_should_not_enable_server_failover_by_default
    assert_nil @cache.client_options[:failover]
  end

  def test_should_allow_configuration_of_custom_options
    options = { client: { tcp_nodelay: true, distribution: :modula } }

    store = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost', options

    assert_equal :modula, store.client_options[:distribution]
    assert_equal true, store.client_options[:tcp_nodelay]
  end

  def test_should_allow_mute_and_silence
    cache = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost'
    cache.mute do
      assert cache.write('foo', 'bar')
      assert_equal 'bar', cache.read('foo')
    end
    refute cache.silence?
    cache.silence!
    assert cache.silence?
  end
end
