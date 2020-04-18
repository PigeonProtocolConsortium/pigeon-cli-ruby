Gem::Specification.new do |s|
  s.name = "pigeon"
  s.version = "0.0.1"
  s.date = "2020-04-20"
  s.summary = "An offline peer-to-peer protocol"
  s.description = "A Ruby client for Pigeon, an offline peer-to-peer protocol"
  s.authors = ["Navigator"]
  s.email = "netscape_navigator@tilde.town"
  s.files = (Dir["views/**/*.erb"] + Dir["lib/**/*.rb"])
  s.homepage = "https://tildegit.org/PigeonProtocolConsortium/pigeon_ruby"
  s.license = "GPL-3.0-or-later"
  s.add_runtime_dependency "thor", "~> 0.20", ">= 0.20.3"
  s.add_runtime_dependency "ed25519", "~> 1.2", ">= 1.2.4"
end
