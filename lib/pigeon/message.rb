require "digest"

module Pigeon
  class Message
    attr_reader :author, :kind, :body, :signature, :depth, :prev

    def render
      template.render.chomp
    end

    def multihash
      tpl = render
      digest = Digest::SHA256.digest(tpl)
      sha256 = Helpers.b32_encode(digest)
      "#{MESSAGE_SIGIL}#{sha256}"
    end

    def initialize(author:,
                   kind:,
                   body:,
                   depth:,
                   prev:,
                   signature:)
      raise MISSING_BODY if body.empty?

      @author = author
      @body = body
      @depth = depth
      @kind = kind
      @prev = prev || Pigeon::NOTHING
      @signature = signature
    end

    def template
      MessageSerializer.new(self)
    end

    def collect_blobs
      ([kind] + body.keys + body.values)
        .select { |x| x.match? Lexer::BLOB_VALUE }
        .uniq
    end
  end
end
