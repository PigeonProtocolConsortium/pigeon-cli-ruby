require "pstore"

module Pigeon
  class Storage
    def self.current
      @current ||= self.new
    end

    def self.reset
      File.delete(PIGEON_DB_PATH) if File.file?(PIGEON_DB_PATH)
      @current = nil
    end

    def add_peer(identity)
      path = Helpers.decode_multihash(identity)
      write { store[PEER_NS].add(identity) }
      identity
    end

    def remove_peer(identity)
      path = Helpers.decode_multihash(identity)
      write { store[PEER_NS].delete(identity) }
      identity
    end

    def block_peer(identity)
      remove_peer(identity)
      write { store[BLCK_NS].add(identity) }
      identity
    end

    def all_peers
      read { store[PEER_NS].to_a }
    end

    def all_blocks
      read { store[BLCK_NS].to_a }
    end

    def get_config(key)
      read { store[CONF_NS][key] }
    end

    def set_config(key, value)
      write { store[CONF_NS][key] = value }
    end

    def set_blob(data)
      raw_digest = Digest::SHA256.digest(data)
      b64_digest = Helpers.b32_encode(raw_digest)
      multihash = [BLOB_SIGIL, b64_digest, BLOB_FOOTER].join("")
      write { store[BLOB_NS][multihash] = data }

      multihash
    end

    def get_blob(blob_multihash)
      read { store[BLOB_NS][blob_multihash] }
    end

    # `nil` means "none"
    def get_message_count_for(mhash)
      raise "Expected string, got #{mhash.class}" unless mhash.is_a?(String) # Delete later
      read { store[COUNT_INDEX_NS][mhash] || 0 }
    end

    def find_all(author)
      all = []
      depth = -1
      last = ""
      until (last == nil) || (depth > 99999)
        last = self.get_message_by_depth(author, depth += 1)
        all.push(last) if last
      end
      return all
    end

    def get_message_by_depth(multihash, depth)
      raise "Expected string, got #{multihash.class}" unless multihash.is_a?(String) # Delete later
      # Map<[multihash(str), depth(int)], Signature>
      key = [multihash, depth].join(".")
      read { store[MESSAGE_BY_DEPTH_NS][key] }
    end

    def message?(multihash)
      read { store[MESG_NS].fetch(multihash, false) }
    end

    def read_message(multihash)
      read { store[MESG_NS].fetch(multihash) }
    end

    def save_message(msg)
      write do
        return msg if store[MESG_NS][msg.multihash]
        insert_and_update_index(msg)
        msg
      end
    end

    private

    def bootstrap
      write do
        # Wait what? Why is there a depth and count
        # index??
        store[MESSAGE_BY_DEPTH_NS] ||= {}
        store[COUNT_INDEX_NS] ||= {}
        store[BLOB_NS] ||= {}
        store[CONF_NS] ||= {}
        store[MESG_NS] ||= {}
        store[BLCK_NS] ||= Set.new
        store[PEER_NS] ||= Set.new
      end
      store
    end

    def store
      if @store
        return @store
      else
        @store = PStore.new(PIGEON_DB_PATH)
        bootstrap
      end
    end

    def insert_and_update_index(message)
      pub_key = message.author.multihash
      # STEP 1: Update MESG_NS, the main storage spot.
      store[MESG_NS][message.multihash] = message

      # STEP 2: Update the "message by author and depth" index
      #         this index is used to find a person's nth
      #         message
      # SECURITY AUDIT: How can we be certain the message is
      # not lying about its depth?
      key = [pub_key, message.depth].join(".")
      store[MESSAGE_BY_DEPTH_NS][key] = message.multihash
      store[COUNT_INDEX_NS][pub_key] ||= 0
      store[COUNT_INDEX_NS][pub_key] += 1
    end

    def transaction(is_read_only)
      store.transaction(is_read_only) { yield }
    end

    def write(&blk); transaction(false, &blk); end
    def read(&blk); transaction(true, &blk); end
  end
end
