module HotStorage
  class FakeRedis
    attr_reader :writes, :events

    def initialize
      @writes = {}
      @events = Hash.new { |h, key| h[key] = [] }
    end

    def set(key, payload, ex: nil)
      @writes[key] = { payload: payload, ex: ex }
      'OK'
    end

    def get(key)
      @writes.dig(key, :payload)
    end

    def xadd(stream_key, fields, maxlen: nil, approximate: nil)
      @events[stream_key] << { fields: fields, maxlen: maxlen, approximate: approximate }
      "#{@events[stream_key].length}-0"
    end
  end
end
