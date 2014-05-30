require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/spec'
require 'mocha/setup'

ENV["RAILS_ENV"] = "test"
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
