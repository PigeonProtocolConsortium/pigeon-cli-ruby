module Pigeon
  class Database
    attr_reader :who_am_i

    def initialize(path: PIGEON_DB_PATH)
      @store = Pigeon::Storage.new(path: path)
      init_ident
    end

    # === PEERS
    def add_peer(p)
      store.add_peer(p)
    end

    def block_peer(p)
      store.block_peer(p)
    end

    def remove_peer(p)
      store.remove_peer(p)
    end

    def peer_blocked?(p)
      store.peer_blocked?(p)
    end

    def all_blocks
      store.all_blocks
    end

    def all_peers
      store.all_peers
    end

    # === MESSAGES
    def all_messages(mhash = nil)
      store.all_messages(mhash)
    end

    def have_message?(multihash)
      store.have_message?(multihash)
    end

    def _save_message(msg_obj)
      store.insert_message(Helpers.verify_message(self, msg_obj))
    end

    def read_message(multihash)
      store.read_message(multihash)
    end

    def get_message_count_for(multihash)
      store.get_message_count_for(multihash)
    end

    def get_message_by_depth(multihash, depth)
      store.get_message_by_depth(multihash, depth)
    end

    def add_message(kind, params)
      publish_draft(new_draft(kind: kind, body: params))
    end

    # Store a message that someone (not the LocalIdentity)
    # has authored.
    def _ingest_message(author:,
                        body:,
                        depth:,
                        kind:,
                        prev:,
                        signature:)
      msg = Message.new(author: RemoteIdentity.new(author),
                        kind: kind,
                        body: body,
                        prev: prev,
                        signature: signature,
                        depth: depth)
      _save_message(msg)
    end

    # === DRAFTS
    def delete_current_draft
      _add_config(CURRENT_DRAFT, nil)
    end

    def new_draft(kind:, body: {})
      old = _get_config(CURRENT_DRAFT)
      if old
        raise STILL_HAVE_DRAFT % old.kind
      end
      _replace_draft(Draft.new(kind: kind, body: body))
    end

    def _replace_draft(draft)
      _add_config(CURRENT_DRAFT, draft)
      draft
    end

    def get_draft
      draft = store._get_config(CURRENT_DRAFT)
      unless draft
        raise MISSING_DRAFT
      end
      draft
    end

    def update_draft(k, v)
      Helpers.update_draft(self, k, v)
    end

    def delete_current_draft
      _add_config(CURRENT_DRAFT, nil)
    end

    # Author a new message.
    def publish_draft(draft = get_draft)
      Helpers.publish_draft(self, draft)
    end

    # === BUNDLES
    def export_bundle(file_path = DEFAULT_BUNDLE_PATH)
      Helpers.mkdir_p(file_path)

      # Fetch messages for all peers
      peers = all_peers + [who_am_i.multihash]
      messages = peers.map do |peer|
        all_messages(peer)
          .map { |multihash| read_message(multihash) }
          .sort_by(&:depth)
      end.flatten

      # Attach blobs for all messages in bundle.
      messages
        .map(&:collect_blobs)
        .flatten
        .uniq
        .map do |mhash|
        blob = get_blob(mhash)
        Helpers.write_to_disk(file_path, mhash, blob)
      end

      # Render messages for all peers.
      content = messages
        .map(&:render)
        .join(BUNDLE_MESSAGE_SEPARATOR)

      File.write(File.join(file_path, MESSAGE_FILE), content + CR)
    end

    def import_bundle(file_path = DEFAULT_BUNDLE_PATH)
      bundle = File.read(File.join(file_path, MESSAGE_FILE))
      tokens = Pigeon::Lexer.tokenize(bundle)
      messages = Pigeon::Parser.parse(self, tokens)
      wanted = Set.new
      messages
        .map(&:collect_blobs)
        .flatten
        .uniq
        .map do |mhash|
        b32 = mhash.gsub(BLOB_SIGIL, "")
        binary = Pigeon::Helpers.b32_decode(b32)
        wanted.add(binary)
      end
      all_files = Dir[File.join(file_path, "*.blb"), File.join(file_path, "*.BLB")]
      all_files.map do |path|
        data = File.read(path)
        raw_digest = Digest::SHA256.digest(data)
        if wanted.member?(raw_digest)
          mhash = BLOB_SIGIL + Helpers.b32_encode(raw_digest)
          rel_path = Helpers.hash2file_path(mhash)
          from = File.join([file_path] + rel_path)
          to = File.join([DEFAULT_BLOB_DIR] + rel_path)
          if !File.file?(to)
            Helpers.write_to_disk(DEFAULT_BLOB_DIR, mhash, data)
          end
        end
      end
      messages
    end

    # === BLOBS
    def get_blob(b)
      store.get_blob(b)
    end

    def add_blob(b)
      store.add_blob(b)
    end

    def have_blob?(b)
      store.have_blob?(b)
    end

    # === DB Management
    def _get_config(k)
      store._get_config(k)
    end

    def _add_config(k, v)
      store._add_config(k, v)
    end

    def reset_database
      store.reset
      init_ident
    end

    private

    attr_reader :store

    def init_ident
      secret = _get_config(SEED_CONFIG_KEY)
      if secret
        @who_am_i = LocalIdentity.new(secret)
      else
        new_seed = SecureRandom.random_bytes(Ed25519::KEY_SIZE)
        _add_config(SEED_CONFIG_KEY, new_seed)
        @who_am_i = LocalIdentity.new(new_seed)
      end
    end
  end
end
