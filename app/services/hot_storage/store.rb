require 'json'

module HotStorage
  class NullRedis
    def set(*); end

    def get(*)
      nil
    end

    def xadd(*)
      '0-0'
    end
  end

  class Store
    DEFAULT_NAMESPACE = 'adivento:hot:v1'.freeze

    class << self
      attr_writer :current

      def current
        @current ||= new
      end

      def default_redis
        @default_redis ||= build_default_redis
      end

      private

      def build_default_redis
        return NullRedis.new if ENV['DISABLE_HOT_STORAGE'] == '1'

        begin
          require 'redis'
        rescue LoadError
          Rails.logger.warn('HotStorage disabled: redis gem missing')
          return NullRedis.new
        end

        redis_url = ENV['REDIS_URL'].to_s
        return NullRedis.new if redis_url.blank?

        client = Redis.new(
          url: redis_url,
          connect_timeout: 0.2,
          read_timeout: 0.2,
          write_timeout: 0.2
        )
        client.ping
        client
      rescue StandardError => e
        Rails.logger.warn("HotStorage disabled: #{e.class}: #{e.message}")
        NullRedis.new
      end
    end

    def initialize(redis: self.class.default_redis, namespace: DEFAULT_NAMESPACE, snapshot_ttl_seconds: 120,
                   stream_maxlen: 5_000)
      @redis = redis
      @namespace = namespace
      @snapshot_ttl_seconds = snapshot_ttl_seconds
      @stream_maxlen = stream_maxlen
    end

    def write_market_snapshot!(market_id:, snapshot:, version:)
      payload = snapshot.merge(version: version).to_json
      @redis.set(snapshot_key(market_id), payload, ex: @snapshot_ttl_seconds)
      payload
    end

    def read_market_snapshot(market_id:)
      raw = @redis.get(snapshot_key(market_id))
      return if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def append_market_event!(market_id:, event_name:, payload:, version:)
      @redis.xadd(
        stream_key(market_id),
        {
          'event' => event_name,
          'version' => version.to_s,
          'payload' => payload.to_json
        },
        maxlen: @stream_maxlen,
        approximate: true
      )
    end

    private

    def snapshot_key(market_id)
      "#{@namespace}:market:#{market_id}:snapshot"
    end

    def stream_key(market_id)
      "#{@namespace}:market:#{market_id}:events"
    end
  end
end
