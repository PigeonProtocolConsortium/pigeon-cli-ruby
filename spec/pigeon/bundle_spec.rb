require "spec_helper"

RSpec.describe Pigeon::Message do
  before(:each) do
    `rm -rf #{Pigeon::DEFAULT_BLOB_DIR}`
    p = Pigeon::DEFAULT_BUNDLE_PATH
    File.delete(p) if File.file?(p)
  end

  let(:db) do
    db = Pigeon::Database.new
    db.reset_database
    db
  end

  def create_fake_messages
    blobs = [db.add_message(db.add_blob("one"), { "a" => "b" }),
             db.add_message("a", { db.add_blob("two") => "b" }),
             db.add_message("a", { "b" => db.add_blob("three") })]
    normal = (1..10)
      .to_a
      .map { |_n| { "foo" => ["bar", "123", SecureRandom.uuid].sample } }
      .map { |d| db.add_message(SecureRandom.uuid, d) }

    blobs + normal
  end

  it "creates a bundle" do
    expected_bundle = create_fake_messages.map(&:render).join("\n\n") + "\n"
    db.export_bundle
    actual_bundle = File.read(File.join(Pigeon::DEFAULT_BUNDLE_PATH, Pigeon::MESSAGE_FILE))
    expect(expected_bundle).to eq(actual_bundle)
  end

  it "does not crash when ingesting old messages" do
    create_fake_messages
    db.export_bundle
    db.import_bundle
  end

  it "does not ingest messages from blocked peers" do
    db.reset_database
    expect(db.all_messages.count).to eq(0)
    antagonist = "USER.YJTH2BBAAAXK2RYKWRXYE0E0ANME1YPZPD8TV5VCS40X3D75AJ3G"
    db.block_peer(antagonist)
    db.import_bundle(BLOCKED_PEER_FIXTURE_PATH)
    expect(db.all_messages.count).to eq(0)
  end

  it "ingests a bundle's blobs" do
    db.reset_database
    blobs = [
      "FILE.622PRNJ7C0S05XR2AHDPKWMG051B1QW5SXMN2RQHF2AND6J8VGPG",
      "FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG",
      "FILE.YPF11E5N9JFVB6KB1N1WDVVT9DXMCHE0XJWBZHT2CQ29S5SEPCSG",
    ]
    db.import_bundle(HAS_BLOB_PATH)
    expect(db.all_messages.count).to eq(3)
    blobs.map do |h|
      expect(db.have_blob?(h)).to be true
      expect(db.get_blob(h)).to be_kind_of(String)
    end
  end
end
