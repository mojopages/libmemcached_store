require 'benchmark'
require 'active_support'

require 'libmemcached_store'
require 'active_support/cache/libmemcached_store'

require 'dalli'
require 'active_support/cache/dalli_store'

puts "Testing with"
puts RUBY_DESCRIPTION
puts "Dalli #{Dalli::VERSION}"
puts "Libmemcached_store #{LibmemcachedStore::VERSION}"

# We'll use a simple @value to try to avoid spending time in Marshal,
# which is a constant penalty that both clients have to pay
@value = []
@marshalled = Marshal.dump(@value)

@servers = ['127.0.0.1:11211']
@key1 = "Short"
@key2 = "Sym1-2-3::45"*4
@key3 = "Long"*40
@key4 = "Medium"*8

N = 2_500

@dalli = ActiveSupport::Cache::DalliStore.new(@servers).silence!
@libm = ActiveSupport::Cache::LibmemcachedStore.new(@servers).silence!

def clear
  @dalli.clear
  @libm.clear
end

def test_method(title, method_name, key, *arguments)
  { dalli: @dalli, libm: @libm }.each do |name, store|
    @job.report("#{title}:#{name}") { N.times { store.send(method_name, key, *arguments) } }
  end
end

def run_method(method_name, key, *arguments)
  [@dalli, @libm].each do |store|
    store.send(method_name, key, *arguments)
  end
end

Benchmark.bm(31) do |x|
  @job = x

  test_method('write:short', :write, @key1, @value)
  test_method('write:long',  :write, @key3, @value)
  test_method('write:raw',   :write, @key4, @value, raw: true)

  puts
  clear

  test_method('read:miss',  :read, @key1)
  test_method('read:miss2', :read, @key1)

  run_method(:write, @key4, @value)
  test_method('read:exist', :read, @key4)

  run_method(:write, @key4, @value, expires_in: 1)
  sleep(1)
  test_method('read:expired', :read, @key2)

  run_method(:write, @key3, @value, raw: true)
  test_method('read:raw', :read, @key3, raw: true)

  puts
  clear

  test_method('exist:miss', :exist?, @key4)

  run_method(:write, @key4, @value)
  test_method('exist:hit', :exist?, @key4)

  puts
  clear

  test_method('delete:miss', :delete, @key4)

  run_method(:write, @key1, @value)
  test_method('delete:hit', :delete, @key1)

  puts
  clear

  run_method(:write, @key4, 0, raw: true)

  test_method('increment', :increment, @key4)
  test_method('decrement', :decrement, @key4)
end