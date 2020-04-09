require "digest"

module Pigeon
  class Message
    attr_reader :author, :kind, :body, :signature, :depth, :prev

    class VerificationError < StandardError; end

    VERFIY_ERROR = "Expected field `%s` to equal %s, got: %s"

    # Store a message that someone (not the LocalIdentity)
    # has authored.
    def self.ingest(author:, body:, depth:, kind:, prev:, signature:)
      new(author: RemoteIdentity.new(author),
          kind: kind,
          body: body,
          prev: prev,
          signature: signature,
          depth: depth).save!
    end

    def render
      template.render.chomp
    end

    def multihash
      tpl = self.render
      digest = Digest::SHA256.digest(tpl)
      sha256 = Helpers.b32_encode(digest)
      "#{MESSAGE_SIGIL}#{sha256}#{BLOB_FOOTER}"
    end

    def save!
      puts "TODO: Make this method private."
      return store.read_message(multihash) if store.message?(multihash)
      verify_depth_prev_and_depth
      verify_signature
      self.freeze
      store.save_message(self)
      self
    end

    private

    def assert(field, actual, expected)
      unless actual == expected
        message = VERFIY_ERROR % [field, actual || "nil", expected || "nil"]
        raise VerificationError, message
      end
    end

    def verify_depth_prev_and_depth
      count = store.get_message_count_for(author.multihash)
      expected_prev = store.get_message_by_depth(author.multihash, count - 1) || Pigeon::EMPTY_MESSAGE
      assert("depth", count, depth)
      assert("prev", prev, expected_prev)
    end

    def verify_signature
      tpl = template.render_without_signature
      Helpers.verify_string(author, signature, tpl)
    end

    def initialize(author:, kind:, body:, depth:, prev:, signature: nil)
      raise MISSING_BODY if body.empty?
      @author = author
      @body = body
      @depth = depth
      @kind = kind
      @prev = prev || Pigeon::EMPTY_MESSAGE
      @signature = signature
    end

    def template
      MessageSerializer.new(self)
    end

    def store
      Pigeon::Storage.current
    end
  end
end
