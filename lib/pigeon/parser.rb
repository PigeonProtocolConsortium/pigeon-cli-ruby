module Pigeon
  class Parser
    class DuplicateKeyError < StandardError; end

    DUPE_KEYS = "Found duplicate keys: %s"

    def self.parse(db, tokens)
      new(db, tokens).parse
    end

    def initialize(db, tokens)
      reset_scratchpad
      @db = db
      @tokens = tokens
      @results = []
    end

    def parse
      @tokens.each_with_index do |token, _i|
        case token.first
        when :AUTHOR then set(:author, token[1])
        when :KIND then set(:kind, token[1])
        when :DEPTH then set(:depth, token[1])
        when :PREV then set(:prev, token[1])
        when :HEADER_END then set(:body, {})
        when :BODY_ENTRY then set(token[1], token[2], @scratchpad[:body])
        when :BODY_END then nil
        when :SIGNATURE then set(:signature, token[1])
        when :MESSAGE_DELIM then finish_this_message!
        end
      end
      @results
    end

    private

    def reset_scratchpad
      @scratchpad = {}
    end

    def finish_this_message!
      @scratchpad.freeze
      unless @db.peer_blocked?(@scratchpad.fetch(:author))
        @results.push(@db._ingest_message(**@scratchpad))
      end
      reset_scratchpad
    end

    def set(key, value, hash = @scratchpad)
      if hash[key]
        raise DuplicateKeyError, (DUPE_KEYS % key)
      else
        hash[key] = value
      end
    end
  end
end
