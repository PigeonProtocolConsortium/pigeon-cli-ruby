module Pigeon
  class Lexer
    attr_reader :bundle_string, :scanner, :tokens
    # TODO: Change all the `{40,90}` values in ::Lexer to real values
    # TODO: Create regexes using string and Regexp.new() for cleaner regexes.
    FEED_VALUE = /@.{40,90}.ed25519/
    DEPTH_COUNT = /\d{1,7}/
    MESG_VALUE = /%.{40,90}.sha256/
    BLOB_VALUE = /&.{40,90}.sha256/
    NULL_VALUE = /NONE/
    STRG_VALUE = /".{1,64}"/
    ALPHANUMERICISH = /[a-zA-Z\d\._]{1,64}/
    ALL_VALUES = [
      FEED_VALUE,
      MESG_VALUE,
      NULL_VALUE,
      STRG_VALUE,
      BLOB_VALUE,
    ].map(&:source).join("|")
    ANY_VALUE = Regexp.new(ALL_VALUES)

    SEPERATOR = /\n/
    AUTHOR = /author #{FEED_VALUE}\n/
    DEPTH = /depth #{DEPTH_COUNT}\n/
    PREV = /prev (#{MESG_VALUE}|#{NULL_VALUE})\n/
    KIND = /kind #{ALPHANUMERICISH}\n/
    BODY_ENTRY = /#{ALPHANUMERICISH}:#{ANY_VALUE}\n/

    FOOTER_ENTRY = /signature .*{40,90}\.sig\.ed25519\n/

    LEXER_STATES = [HEADER = :header, BODY = :body, FOOTER = :footer]

    def self.tokenize(bundle_string)
      # TODO: Maybe move #tokeinze into constructor.
      new(bundle_string).tokenize
    end

    def tokenize
      until scanner.eos?
        puts scanner.matched || "No match"
        case @state
        when HEADER then do_header
        when BODY then do_body
        when FOOTER then do_footer
        end
      end
    end

    private

    def initialize(bundle_string)
      @bundle_string = bundle_string
      @scanner = StringScanner.new(bundle_string)
      @tokens = []
      @state = HEADER
    end

    def flunk!
      raise "Syntax error at #{scanner.pos}"
    end

    def add_terminator!
      @tokens << [:TERMINATOR]
    end

    def do_header
      if scanner.scan(AUTHOR)
        author = scanner.matched.chomp.gsub("author ", "")
        @tokens << [:AUTHOR, author]
        return
      end

      if scanner.scan(DEPTH)
        depth = scanner.matched.chomp.gsub("depth ", "").to_i
        @tokens << [:DEPTH, depth]
        return
      end

      if scanner.scan(PREV)
        prev = scanner.matched.chomp.gsub("prev ", "")
        @tokens << [:PREV, prev]
        return
      end

      if scanner.scan(KIND)
        kind = scanner.matched.chomp.gsub("kind ", "")
        @tokens << [:KIND, kind]
        return
      end

      if scanner.scan(SEPERATOR)
        @state = BODY
        add_terminator!
        return
      end
      flunk!
    end

    def do_body
      if scanner.scan(BODY_ENTRY)
        key, value = scanner.matched.chomp.split(":")
        @tokens << [:BODY_ENTRY, key, value]
        return
      end

      if scanner.scan(SEPERATOR)
        @state = FOOTER
        add_terminator!
        return
      end

      flunk!
    end

    def do_footer
      # Reset the lexer to ingest the next entry.
      # If scanner.eos? == true, it will just terminate.

      if scanner.scan(FOOTER_ENTRY)
        sig = scanner.matched.strip.gsub("signature ", "")
        @tokens << [:SIGNATURE, sig]
        return
      end

      if scanner.scan(SEPERATOR)
        @state = HEADER
        add_terminator!
      else
        raise "Parse error at #{scanner.pos}. Did you add two carriage returns?"
      end
    end
  end
end
