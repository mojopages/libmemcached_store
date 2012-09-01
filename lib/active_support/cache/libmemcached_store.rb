require 'memcached'
require 'memcached/get_with_flags'

require 'digest/md5'

module ActiveSupport
  module Cache

    #
    # Store using memcached gem as client
    #
    # Global options can be passed to be applied to each method by default.
    # Supported options are
    # * <tt>:compress</tt> : if set to true, data will be compress before stored
    # * <tt>:compress_threshold</tt> : specify the threshold at which to compress
    # value, default is 4K
    # * <tt>:namespace</tt> : prepend each key with this value for simple namespacing
    # * <tt>:expires_in</tt> : default TTL in seconds for each. Default value is 0, i.e. forever
    # Specific value can be passed per key with write and fetch command.
    #
    # Options can also be passed direclty to the memcache client, via the <tt>:client</tt>
    # option. For example, if you want to use pipelining, you can use
    # :client => { :no_block => true }
    #
    class LibmemcachedStore < Store
      attr_reader :addresses

      DEFAULT_CLIENT_OPTIONS = { distribution: :consistent_ketama, binary_protocol: true, default_ttl: 0 }
      ESCAPE_KEY_CHARS = /[\x00-\x20%\x7F-\xFF]/n
      DEFAULT_COMPRESS_THRESHOLD = 4096
      FLAG_COMPRESSED = 0x2

      def initialize(*addresses)
        addresses.flatten!
        options = addresses.extract_options!
        client_options = options.delete(:client) || {}
        if options[:namespace]
          client_options[:prefix_key] = options.delete(:namespace)
          client_options[:prefix_delimiter] = ':'
          @namespace_length = client_options[:prefix_key].length + 1
        else
          @namespace_length = 0
        end
        client_options[:default_ttl] = options.delete(:expires_in).to_i if options[:expires_in]

        @options = options.reverse_merge(compress_threshold: DEFAULT_COMPRESS_THRESHOLD)
        @addresses = addresses
        @cache = Memcached.new(@addresses, client_options.reverse_merge(DEFAULT_CLIENT_OPTIONS))
        @cache.instance_eval { send(:extend, GetWithFlags) }
      end

      def fetch(key, options = nil)
        if block_given?
          key = expanded_key(key)
          unless options && options[:force]
            entry = instrument(:read, key, options) do |payload|
              payload[:super_operation] = :fetch if payload
              read_entry(key, options)
            end
          end

          if entry.nil?
            result = instrument(:generate, key, options) do |payload|
              yield
            end
            write_entry(key, result, options)
            result
          else
            instrument(:fetch_hit, key, options) { |payload| }
            entry
          end
        else
          read(key, options)
        end
      end

      def read(key, options = nil)
        key = expanded_key(key)
        instrument(:read, key, options) do |payload|
          entry = read_entry(key, options)
          payload[:hit] = !!entry if payload
          entry
        end
      end

      def write(key, value, options = nil)
        key = expanded_key(key)
        instrument(:write, key, options) do |payload|
          write_entry(key, value, options)
        end
      end

      def delete(key, options = nil)
        key = expanded_key(key)
        instrument(:delete, key) do |payload|
          delete_entry(key, options)
        end
      end

      def exist?(key, options = nil)
        key = expanded_key(key)
        instrument(:exist?, key) do |payload|
          !read_entry(key, options).nil?
        end
      end

      def increment(key, amount = 1, options = nil)
        key = expanded_key(key)
        instrument(:increment, key, amount: amount) do
          @cache.incr(escape_and_normalize(key), amount)
        end
      rescue Memcached::NotFound
        nil
      rescue Memcached::Error => e
        log_error(e)
        nil
      end

      def decrement(key, amount = 1, options = nil)
        key = expanded_key(key)
        instrument(:decrement, key, amount: amount) do
          @cache.decr(escape_and_normalize(key), amount)
        end
      rescue Memcached::NotFound
        nil
      rescue Memcached::Error => e
        log_error(e)
        nil
      end

      def read_multi(*names)
        names.flatten!
        options = names.extract_options!

        return {} if names.empty?

        mapping = Hash[names.map {|name| [escape_and_normalize(expanded_key(name)), name] }]
        raw_values, flags = @cache.get(mapping.keys, false, true)

        values = {}
        raw_values.each do |key, value|
          values[mapping[key]] = deserialize(value, options[:raw], flags[key])
        end
        values
      end

      def clear
        @cache.flush
      end

      def stats
        @cache.stats
      end

      protected

      def read_entry(key, options = nil)
        options ||= {}
        raw_value, flags = @cache.get(escape_and_normalize(key), false, true)
        deserialize(raw_value, options[:raw], flags)
      rescue Memcached::NotFound
        nil
      rescue Memcached::Error => e
        log_error(e)
        nil
      end

      def write_entry(key, entry, options = nil)
        options = options ? @options.merge(options) : @options
        method = options[:unless_exist] ? :add : :set
        entry = options[:raw] ? entry.to_s : Marshal.dump(entry)
        flags = 0

        if options[:compress] && entry.bytesize >= options[:compress_threshold]
          entry = Zlib::Deflate.deflate(entry)
          flags |= FLAG_COMPRESSED
        end

        @cache.send(method, escape_and_normalize(key), entry, options[:expires_in].to_i, false, flags)
        true
      rescue Memcached::Error => e
        log_error(e)
        false
      end

      def delete_entry(key, options = nil)
        @cache.delete(escape_and_normalize(key))
        true
      rescue Memcached::NotFound
        false
      rescue Memcached::Error => e
        log_error(e)
        false
      end

      private

      def deserialize(value, raw = false, flags = 0)
        value = Zlib::Inflate.inflate(value) if (flags & FLAG_COMPRESSED) != 0
        raw ? value : Marshal.load(value)
      rescue TypeError, ArgumentError
        value
      end

      def escape_and_normalize(key)
        key = key.to_s.force_encoding("BINARY").gsub(ESCAPE_KEY_CHARS) { |match| "%#{match.getbyte(0).to_s(16).upcase}" }
        key_length = key.length

        return key if @namespace_length + key_length <= 250

        max_key_length = 213 - @namespace_length
        "#{key[0, max_key_length]}:md5:#{Digest::MD5.hexdigest(key)}"
      end

      def expanded_key(key) # :nodoc:
        return key.cache_key.to_s if key.respond_to?(:cache_key)

        case key
        when Array
          if key.size > 1
            key = key.collect { |element| expanded_key(element) }
          else
            key = key.first
          end
        when Hash
          key = key.sort_by { |k,_| k.to_s }.collect { |k, v| "#{k}=#{v}" }
        end

        key.to_param
      end

      def log_error(exception)
        return unless logger && logger.error?
        logger.error "MemcachedError (#{exception.inspect}): #{exception.message}"
      end
    end
  end
end
