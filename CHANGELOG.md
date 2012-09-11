# Changelog

## 0.5.0 (unreleased)
  * Add benchmarks
  * Remove the use of ActiveSupport::Entry which was a performance bottleneck #3

## 0.4.0
  * Optimize read_multi to only make one call to memecached server
  * Update test suite to reflect Rails' one
  * Add session store tests