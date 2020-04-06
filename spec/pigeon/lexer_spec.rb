require "spec_helper"

RSpec.describe Pigeon::Lexer do
  EXPECTED_TOKENS1 = [
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "1db28f82-904c-4a31-a28a-b2da5f7be398"],
    [:PREV, "NONE"],
    [:DEPTH, 0],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"bar\""],
    [:BODY_END],
    [:SIGNATURE, "FZ8FJRCXX1PPN43VCD45PFWANJGYPZVA9JQ4NHBQGBFBYJG6CA31NFEXK67Z90R2DBS3NGT8M0CBYG4CMDKCBSRFW838J56T4F3K40G.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "375de134-161d-47c8-8ff6-e80776155d39"],
    [:PREV, "%4541G6XQ9VBG8N0VXCF4K04F0AX1JQNJD3NCPV0JYHQJV0KVJW5G.sha256"],
    [:DEPTH, 1],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"810c05f8-d594-493a-a540-21d5c1cb52c6\""],
    [:BODY_END],
    [:SIGNATURE, "5DVXT2X4T5XRQ99FB6PAJ19F3QA2V37QWCZADYQDGGH9NYG1JCTTCH5ETGJCPQZXT3A93GASGYAZ93PN836G15R7MM8KM1KK1HX501G.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "483290a3-e79d-4d03-97d0-85439bd716f3"],
    [:PREV, "%4D9R2SR4PCQEZ542CPXPS2ZHPRSSVXEVENFF91TP82FA45Y1RE5G.sha256"],
    [:DEPTH, 2],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"a88b270e-fa4b-40b7-ba35-fa498f9adfc6\""],
    [:BODY_END],
    [:SIGNATURE, "27B87NF1R6ZCKWTD49XXC5DAVJD1TN7K0JJA2RFTNG1QSSEBS9YX71YPZ5A2J7WP8B0QZH259B6108CJSX4GY8X8N8B1Y2V2SSWGR08.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "4f3b925e-a8fd-4780-a357-1d67eca03459"],
    [:PREV, "%1N8Q1NZKW29CPFTTGNNVD8DZE99Q0KNF5JYN3VW9545S5DB69KKG.sha256"],
    [:DEPTH, 3],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"bar\""],
    [:BODY_END],
    [:SIGNATURE, "15Z9J3MAB1TX7BJPPKRA8NK097J89G1B6QNAD7J5GV6P1WC3EX3SXJFWE4D0GFQJFA0HR74RNEYSFSAHNHBKBMK0Z7C6NY7HWASQG38.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "8aeebbd8-3317-4de0-a770-1abe390af126"],
    [:PREV, "%JTEFPAT798AGDPKPHRMAV36GZAFNEBEMR5ZA9YHNJX0W9HFSP8EG.sha256"],
    [:DEPTH, 4],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"123\""],
    [:BODY_END],
    [:SIGNATURE, "XMGXES56E3EWFXXYPCD81SPNQPZ0NDXDQ0X366R3AHEF75GJVR74RW6F6HNDRWBJ2Z1SSC45N0MTK92MDHS1BXSMC3QJTQBEPN8TW0R.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "80c5cd4d-f9b6-447f-9d0e-1065ee563d7f"],
    [:PREV, "%8X06YEJEP256CQ0M2A04ARW68ABAD4EKSJE76XDF5CDAMJ5Q5NWG.sha256"],
    [:DEPTH, 5],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"bar\""],
    [:BODY_END],
    [:SIGNATURE, "HCP8ECPYW1J9QW7HZKNYEJSG5B59NKBZX4YDYQCW9PWTRECQGT8CR2VJ63WBGE5PMQFWHQJQGS9FQREMVSTNTVQEQRMP242HJFHCP10.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "dc2da357-99bb-44ab-811b-1e305b73b8f9"],
    [:PREV, "%669MW82Y549827TWM70AZV7K2JS9RP96W8AMGYARFH7YDENJ0M9G.sha256"],
    [:DEPTH, 6],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"123\""],
    [:BODY_END],
    [:SIGNATURE, "KXFCZVMWQHDP9D950AMFXN6MXNYZ3KTMZ30Y29N3BEE6Y9ZSM7BE2SJKKCDMVFSST17EJKFZJ173ZDCC9ZTCM6GJASE2JB3RAW8ZY0R.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "e6416139-2e25-4b0a-95c2-d8fc2bece4cf"],
    [:PREV, "%HBXCMMYD7Y2NGSB7X05X1HQ21YYJZEN7D5RKV6KW83KN6R0RCXK0.sha256"],
    [:DEPTH, 7],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"123\""],
    [:BODY_END],
    [:SIGNATURE, "BMGDDWQ4S9XVZZHMWFHJCVTAQXDHEYC2MX05DK7N0KDW2EP36AVDS76YS2ZNNR1K3VHN6EEJHW5SEF72QXB8QJT330RQNXTXFDPX81G.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "1fbf93de-e1fb-41ce-9f23-b275b5aa8578"],
    [:PREV, "%DHTGB2NFWHQWDV3PPZVP2DV8CGXAAVA12KV0E7VQZE6T6STHGJC0.sha256"],
    [:DEPTH, 8],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"bar\""],
    [:BODY_END],
    [:SIGNATURE, "E4TZJVQ3ZHY9KBB681FDZX8F516NQ5S02R2SCMKNGY15AFY972X75C27VVZ5BV31ZRTKK6YWW1R76W43FSSCBEPRFWJ5TG39TJMGP08.sig.ed25519"],
    [:MESSAGE_END],
    [:AUTHOR, "@VG44QCHKA38E7754RQ5DAFBMMD2CCZQRZ8BR2J4MRHHGVTHGW670.ed25519"],
    [:KIND, "aca35bce-12b4-4c67-8e06-f62e5b97c7aa"],
    [:PREV, "%3AG0M4483SPP3GCERE25RWZF50Y8CYCJANC2SRNHT4X1N1S37110.sha256"],
    [:DEPTH, 9],
    [:HEADER_END],
    [:BODY_ENTRY, "foo", "\"123\""],
    [:BODY_END],
    [:SIGNATURE, "3NWJ65FGX914DDHWSF17BMAWKMDDMP4D0661WZK0Y928RB927N8NM2CGK9Y5P8RYGQ2FRGETSQYY5HQX2SKBT81ETRKVB3X56YBGC1G.sig.ed25519"],
    [:MESSAGE_END],
  ]

  MESSAGE_LINES = [
    "author @WEf06RUKouNcEVURslzHvepOiK4WbQAgRc_9aiUy7rE=.ed25519",
    "kind unit_test",
    "prev NONE",
    "depth 0",
    "",
    "foo:\"bar\"",
    "",
    "signature hHvhdvUcrabhFPz52GSGa9_iuudOsGEEE7S0o0WJLqjQyhLfgUy72yppHXsG6T4E21p6EEI6B3yRcjfurxegCA==.sig.ed25519",
  ].freeze

  let(:message) do
    draft = Pigeon::Draft.create(kind: "unit_test")
    draft["foo"] = "bar"
    Pigeon::Message.publish(draft)
  end

  before(:each) do
    Pigeon::Storage.reset
    Pigeon::LocalIdentity.reset
  end

  it "tokenizes a bundle" do
    bundle = File.read("./spec/fixtures/normal.bundle")
    tokens = Pigeon::Lexer.tokenize(bundle)
    EXPECTED_TOKENS1.each_with_index do |item, i|
      expect(tokens[i]).to eq(EXPECTED_TOKENS1[i])
    end
  end

  it "tokenizes a single message" do
    string = message.render
    tokens = Pigeon::Lexer.tokenize(string)
    hash = tokens.reduce({ BODY: {} }) do |h, token|
      case token.first
      when :HEADER_END, :BODY_END, :MESSAGE_END
        h
      when :BODY_ENTRY
        h[:BODY][token[1]] = token[2]
      else
        h[token.first] = token.last
      end
      h
    end

    expect(hash[:AUTHOR]).to eq(message.author.public_key)
    expect(hash[:BODY]).to eq(message.body)
    expect(hash[:DEPTH]).to eq(message.depth)
    expect(hash[:KIND]).to eq(message.kind)
    expect(hash[:PREV]).to eq Pigeon::EMPTY_MESSAGE
    expect(hash[:SIGNATURE]).to eq(message.signature)
  end

  it "catches syntax errors" do
    e = Pigeon::Lexer::LexError
    [
      MESSAGE_LINES.dup.insert(3, "@@@").join("\n"),
      MESSAGE_LINES.dup.insert(5, "@@@").join("\n"),
      MESSAGE_LINES.dup.insert(7, "@@@").join("\n"),
    ].map do |bundle|
      expect { Pigeon::Lexer.tokenize(bundle) }.to raise_error(e)
    end
  end
end
