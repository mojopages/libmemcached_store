# Changelog

## 0.7.1
  # Drop suppport for Rails 3.2 and add tests for Rails 4.1
  # Fix bug with race_condition_ttl and no expires_in (grosser)

## 0.7.0
  * Add support for memcached 1.7 (grosser)
  * Test with Rails 4 (grosser)
  * Add race_condition_ttl option to #fetch (grosser)

## 0.6.2
  * Add :hit to the #fetch payload

## 0.6.1
 * Subclass Memcached instead of modifying the instance (staugaard)

## 0.6.0
  * New gem name _libmemcached_store_
  * Handle Memcached::Error in read_multi (staugaard)

## 0.5.1
  * Remove warning from latest version of mocha
  * Make #clear compatible with Rails.cache#clear (grosser)

## 0.5.0
  * Use Memcached#exist if available (performance improvement ~25%)
  * Correctly escape bad characters and too long keys
  * Add benchmarks
  * Remove the use of ActiveSupport::Entry which was a performance bottleneck #3

## 0.4.0
  * Optimize read_multi to only make one call to memecached server
  * Update test suite to reflect Rails' one
  * Add session store tests