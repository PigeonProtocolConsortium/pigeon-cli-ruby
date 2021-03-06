# Ruby API Follow Along Tutorial

## Introduction and Intended Audience

Pigeon is a peer-to-peer log database that serves the needs of off grid and delay-tolerant systems.
Pigeon Ruby is a Ruby-based database client that is interoperable with other compliant Pigeon Protocol clients.
It allows users to manage replicated, distributed log databases. Pigeon makes this possible even on systems with no internet access via sneakernet, thanks to a bundle file specification and extreme delay tolerance properties.

This document will teach you how to:

 * Create and manage a database.
 * Build messages using drafts.
 * Manage and query existing messages.
 * Replicate a database among peers.
 * Attach binary files to messages.
 * Communicate with remote databases using "bundles".

This guide assumes you are familiar with Ruby and the Pigeon Protocol. For an introduction to the protocol, see our protocol specification [here](https://github.com/PigeonProtocolConsortium/pigeon-spec).

Below is a list of all methods needed to run a Pigeon node. Pigeon strives to have a _natural_ API rather than a simple one, which means you may not need to know every single method to operate a node successfully.

**BLOB METHODS:** `#add_blob`,`#get_blob`

**BUNDLE METHODS:** `#export_bundle`, `#import_bundle`

**DRAFT METHODS:**  `#publish_draft`, `#delete_current_draft`, `#get_draft`, `#new_draft`, `#update_draft`

**HELPER METHODS:** `#who_am_i`, `#get_message_by_depth`, `#get_message_count_for`, `#reset_database`

**MESSAGE METHODS:** `#add_message`, `#all_messages`, `#read_message`, `#have_message`

**PEER METHODS:** `#all_peers`, `#add_peer`, `#remove_peer`, `#all_blocks`, `#block_peer`, `#peer_blocked`

**Note to application developers:** Please let us know what you build! Raise an issue with your project so we can add it to the README.

## Installation

Installation steps change over time. Please see [README.md](README.md) for the most up-to-date information.

## Creating a Database Object

When building Pigeon-based applications, a `Pigeon::Database` object controls all interactions with the database.
For the rest of the tutorial we will use the variable name `db` to refer to the current database.

You can create your own database with the following steps:

```ruby
require "pigeon"
db = Pigeon::Database.new(path: "pigeon.db")
# => #<Pigeon::Database:0x000055a1ecca45e8>
```

An optional `path:` argument can be passed to `Pigeon::Database.new`. This arg will default to `pigeon.db` within the local directory if not provided. We recommend this default as it will allow you to use the [command line interface](cli_tutorial.md) more effectively.

If at any point you wish to start the tutorial over, you can reset your local database with the following command:

```ruby
db.reset_database
```

One note about the `pigeon.db` file before moving to the next section: Do not share the `pigeon.db` file with anyone. Doing so will compromise the tamper-resistant properties of Pigeon and allow bad actors to forge messages using your name. Use `bundles` to safely share data with remote peers (covered later).

## Working with Drafts

A `message` is the basic building block of a Pigeon database. As mentioned in the [protocol spec](https://github.com/PigeonProtocolConsortium/pigeon-spec), there are three parts to a message:

 * A header containing a `kind` field (similar to an email subject line) plus some additional meta data used by protocol clients.
 * A body containing user definable key / value pairs.
 * A footer containing a Crockford Base32 encoded ED25119 signature to prevent forgery.

As a convenience, the Pigeon Ruby client allows developers to keep zero or one "draft" messages. A draft message is a log message that has not been signed and has not been committed to the database. Think of it as your own personal scratchpad.

A draft is not part of the protocol spec. It is a convenience provided to users of this library. You could absolutely write messages by hand, calculate their signatures, convert everything to Base32 and manually add them to the database. This would be extremely tedious, however, so the draft functionality was added for convenience.

The examples below will center around the creation of a fictitious gardening journal app, a use case that Pigeon is well suited for.

Let's see if we have a draft to work with:

```ruby
db.get_draft
RuntimeError: NO DRAFT. CREATE ONE FIRST. Call db.new_draft(kind:, body:)
from lib/pigeon/database.rb:104:in `get_draft'
```

We do not have a draft yet. We need to create one:

```ruby
db.new_draft(kind: "garden_diary", body: {"message_text"=>"Tomato plant looking healthy."})
=> #<Pigeon::Draft:0x00005603ed399b48 @author="NONE",
#    @body={"greeting"=>"\"Hello, world!\""}, @depth=-1, @kind="example123",
#    @prev="NONE", @signature="NONE">
```

The command above creates a new draft entry of kind `garden_entry` with one key/value pair in the body. We can view the draft at any time via `#get_draft`:

```ruby
db.get_draft
# => #<Pigeon::Draft:0x00005603ed81e830 @author="NONE",
#      @body={"greeting"=>"\"Hello, world!\""}, @depth=-1,
#      @kind="example123", @prev="NONE",
#      @signature="NONE">
```

Since the draft has not been published to the feed, its contents are mutable. We can add a new key/value pair to the message body with the following command:

```ruby
db.update_draft("current_mood", "Feeling great")
# => "\"Feeling great\""
```

A few notes about this draft message:

 * `"garden_diary` is the message `kind`. This is definable by application developers and helps determine the type of message we are dealing with. A fictitious diary app might have other entries such as `"status_update"` or `"photo_entry"`. It depends on the application you are building.
 * I used string keys for the `"message_text"` body entry rather than symbols or numbers. This is because you can only use strings for key / value pairs (no `:symbols` or numbers). Later on we will learn how to attach files to messages.
 * The `body:` part is optional. I could have called `db.new_draft(kind: "garden_diary")` and added key / value pairs to the body later.

Let's take a final look at our draft message. To get a more human readable version, I can use the `render_as_draft` method on a `Draft` object:

```ruby
human_readable_string = db.get_draft.render_as_draft
# => "author DRAFT\nkind garden_dia...."
puts human_readable_string
# => author DRAFT
#    depth DRAFT
#    kind garden_diary
#    prev DRAFT
#
#    greeting:"Hello, world!"
#    current_mood:"Feeling great"
```

Some interesting things about the draft we just rendered:

 * Unlike a message, a draft has no signature (yet).
 * The `author`, `kind`, `prev`, `depth` properties are all set to `"DRAFT"`. Real values will be populated when we finally publish the draft.

If we want to start over, we can delete a draft via `delete_current_draft`:

```ruby
db.delete_current_draft
# => nil
```

Let's not do this, though. Instead, we will publish this draft in the next section.

## Turning Drafts Into Messages

Now that I am happy with my draft, I can publish it. Once published, my message cannot be modified, so it is very important to visually inspect a draft with `db.get_draft` before proceeding.
Since we did that in the last step, I will go ahead and publish the message:

```
my_message = db.publish_draft
=> #<Pigeon::Message:0x000055a751032c28
 @author=#<Pigeon::RemoteIdentity:0x000055a751032cf0 @multihash="USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG">,
 @body={"greeting"=>"\"Hello, world!\"", "current_mood"=>"\"Feeling great\""},
 @depth=0,
 @kind="garden_diary",
 @prev="NONE",
 @signature="QNY...208">
```

Let's look at our new message in a human-readable way:

```ruby
puts my_message.render
# author USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG
# depth 0
# kind garden_diary
# prev NONE
#
# greeting:"Hello, world!"
# current_mood:"Feeling great"
#
# signature QNY...208
```

Unlike our draft, the message has a signature. The header fields are also populated.

In the next section, we will learn more about messages.

## Working With Messages

Drafts can be helpful when you are building a message incrementally and need a place to temporarily store things between application restarts.
What about when you have all the information you need and want to publish immediately?

In those cases, you can call `db.add_message` and your message will be published to your database immediately:

```ruby
message = db.add_message("garden_entry", {"message_text" => "The basil is just OK", "current_mood" => "content"})
# => #<Pigeon::Message:0x00005653352af998
#  @author=#<Pigeon::RemoteIdentity:0x00005653352afa38 @multihash="USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG">,
#  @body={"message_text"=>"\"The basil is just OK\"", "current_mood"=>"\"content\""},
#  @depth=1,
#  @kind="garden_entry",
#  @prev="TEXT.NPNQZAP9CB79GP8J0SN52F38EBJ9WV370HX6MVZD3XB804TVQQB0",
#  @signature="95E...J3G">

puts message.render
# author USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG
# depth 1
# kind garden_entry
# prev TEXT.NPNQZAP9CB79GP8J0SN52F38EBJ9WV370HX6MVZD3XB804TVQQB0
#
# message_text:"The basil is just OK"
# current_mood:"content"
#
# signature 95E...J3G
```

We should now have 2 messages in the local database.
Let's take a look using the `db.all_messages` method:

```ruby
db.all_messages
# => ["TEXT.NPN...QB0", "TEXT.444...92G"]
```

The `#all_messages` method returns an array containing every message multihash in the database. We can then pass the multihash to the `db.read_message` method to retrieve the corresponding `Pigeon::Message` object.

Let's look at the old log message we created from a draft previously:

```ruby
old_message = db.read_message("TEXT.444CC4NFHGQDQEZ6B6HSEPNZAZ80RSQF8TCAX8QR9NBR5T0XX92G")
# => #<Pigeon::Message:0x0000565335384f08
#  @author=#<Pigeon::RemoteIdentity:0x0000565335384da0 @multihash="USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG">,
#  @body={"message_text"=>"\"The basil is just OK\"", "current_mood"=>"\"content\""},
#  @depth=1,
#  @kind="garden_entry",
#  @prev="TEXT.NPNQZAP9CB79GP8J0SN52F38EBJ9WV370HX6MVZD3XB804TVQQB0",
#  @signature="95E...J3G">

puts old_message.render
# author USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG
# depth 1
# kind garden_entry
# prev TEXT.NPNQZAP9CB79GP8J0SN52F38EBJ9WV370HX6MVZD3XB804TVQQB0

# message_text:"The basil is just OK"
# current_mood:"content"

# signature 95E...J3G
```

Additionally, there is a `have_message?` helper that let's us know if we have a message in the local DB. It will return a `Pigeon::Message` (if found) or `false`:

```ruby
db.have_message?("TEXT.QPNQGRBREXN4CB49RFZ8SQGXD98Z46FS08QH5ZATT6NE2HACC40X")
# => false
```

## Working with Peers

---
STOPPED HERE.

Building a gardening diary is not very fun unless there is a way of sharing your work. Pigeon supports data transfer through the use of peers. When a peer adds you to their local machine, they begin replicating your database on their machine, thereby giving them access to your diary entries and also creating a redundant backup.

As we learned in the last section, Pigeon messages have a unique ID ("multihash"). Every message starts with the word "TEXT." and is followed by a base32 string of digits and letters. Much like messages, every Pigeon database has a unique identifier to identify itself. A database's multihash starts with the word "USER.". Like a message multihash, it is a long string of base32 characters:

```
USER.58844MCNB7ZF7HVKYFRBR7R7E75T8YXP4JBR267AS09RNMHEG3EG
```

We can call `db.who_am_i` to determine our local database multihash:

```ruby
me = db.who_am_i
# => #<Pigeon::LocalIdentity:0x0000558496ad4bf0 @seed="___", @signing_key=#<Ed25519::SigningKey:0x0000558496ad4bc8>>
```

`db.who_am_i` returns a `Pigeon::LocalIdentity` rather than a string (which is what we want). To get results in a more copy/pastable format, call `#multihash` on the `LocalIdentity` object:

```ruby
puts me.multihash
# USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG
```

You can send this string to all your friends so they can add you as a peer to their respective databases.
Let's add a friend to our database now.
My friend has informed me her Pigeon identity is `"USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"`:

```ruby
db.add_peer("USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G")
# => "USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"
```

My client will now keep a local copy of my friend's DB on disk at all times, assuming I have received a "bundle" for the user. Since Pigeon is an offline-only protocol, she will need to mail me an SD Card with her files. We will cover this later in the "Bundles" section.

If you ever lose track of who your peers are, you can call `db.all_peers` to get a list:

```ruby
db.all_peers
# => ["USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"]
```

You can also remove peers if you no longer need to replicate their messages:

```ruby
db.remove_peer("USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G")
# => "USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"
db.all_peers
# => []
```

It is also possible to block peers as needed via `db.block_peer`. `block_peer` is _not_ the same as `remove_peer`. Blocking a peer will prevent gossip from flowing through your database. All of their messages will be ignored and none of your peers will be able to retrieve their messages through you via gossip. When you block a peer, you are essentially imposing an embargo against them. Bundles from blocked peers will neither be imported nor exported under any circumstance.

```ruby
db.block_peer("USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G")
# => "USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"

db.all_blocks
# => ["USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G"]

db.peer_blocked?("USER.753FT97S1FD3SRYPTVPQQ64F7HCEAZMWVBKG0C2MYMS5MJ3SBT6G")
# => true
```

## Querying the Database

The client offers minimal query capabilities and indexes. More will be added at a later date. Please raise an issue if you are interested in helping. Feature requests are welcome.

### Fetch a Message by Feed Identity + Message Depth

```ruby
my_peer = "USER.MF312A76JV8S1XWCHV1XR6ANRDMPAT2G5K8PZTGKWV354PR82CD0"
db.get_message_by_depth(my_peer, 1)
# => "%6JD96QB2EQ30EN3DMHH50NXMR0RZ2GMH43P2DZB3HN6PE6NFE9A0.sha256"
```

### Fetch Total Number of Messages in a Feed

```ruby
db.get_message_count_for(my_peer)
# => 23
```

## Attaching Files to Messages

There are limits to the usefulness (and size) of text content for a Pigeon message. When building a gardening diary app, a user will eventually want to attach garden photos to their entries.

Pigeon supports message file attachments in the form of [blobs](https://en.wikipedia.org/wiki/Binary_large_object).

Once you have added a blob to your local database, it can be attached to messages using the special blob multihash string. Passing arbitrary binary data as a string via `db.add_blob(binary_data)` will do two things:

1. Store the file in your local database (unless we already have a copy)
2. Return a 57 character blob multihash, which can be used to reference the file inside of a message.

```ruby
binary_data = File.read("kitty_cat.gif")
db.add_blob(binary_data)
# => "FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG"
```

Creating a blob returns a blob multihash (`&FV0...MRG.sha256`) which can be attached to a message in the form of keys or values:

```ruby
the_blob_from_before = "FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG"
msg = db.add_message("photo", {"my_cat_picture" => "FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG"})
puts msg.render
# author USER.6DQ4RRNBKJ2T4EY5E1GZYYX6X6SZXV1W0GNH1HA4KGKA5KZ2Y2DG
# depth 2
# kind photo
# prev TEXT.444CC4NFHGQDQEZ6B6HSEPNZAZ80RSQF8TCAX8QR9NBR5T0XX92G
#
# my_cat_picture:FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG
#
# signature WT96XNJ6T006YS51ZDVPT1A7DJW2E4BTBZF66WHHWMKEP35MZ0YD30C32M8WQ85VK19SQFK47MXPEDMWW1GC0RV5XPYHT6WNDMGZM1R
```

If you want to retrieve a blob later, you can pass the blob multihash to `db#get_blob`. The client will return it as binary data.

```ruby
db.get_blob("FILE.FV0FJ0YZADY7C5JTTFYPKDBHTZJ5JVVP5TCKP0605WWXYJG4VMRG")
# => "GIF89aX\u0000\u001F\u0000\xD58\u0000\u0000\u0000\u0000...
```

## Communication with Peers via "Bundles"

Eventually, you will want to share your log messages with a peer, either as a form of communication or for the sake of creating redundant backups.

All data transfer operations in Pigeon are file based. To export data from your local database, one must create a "bundle", which is a file directory with a very specific layout. You can take this directory structure and burn it to a DVD-R, Zip and email, host on an HTTP server, seed it as a torrent, etc..

Think of bundles as a specialized archive format that a Pigeon-compliant database can easily ingest. The bundle mechanism will **package all blobs and messages into a single exportable directory structure automatically**. As long as your peer's client is compliant with the Pigeon spec, they will be replicated onto the peer's machine upon import.


Pigeon does not specify transport or compression concerns, but any reliable file transfer method is possible. For example, applying GZip compression to a bundle is a great idea, but the spec itself does not dictate how to do this. This is particularly true for network-related concerns. The Pigeon spec will never reference network transport in the spec.

In the example below, I will create a bundle called `"bundle_for_my_peer"`.

```ruby
db.export_bundle("bundle_for_my_peer")
```

After running this command, a directory with the name `bundle_for_my_peer` will appear in the current directory. I can send this directory to my peer using any reliable file transfer method.

Examples of possible file transfer mechanisms:

 * Host the directory on an HTTP / FTP server.
 * Apply ZIP compression and put it onto optical media (such as a CD-R)
 * Move the bundle onto a USB thumb drive with or without compression.

If you wish to ingest a peer's message, you can perform the operation in reverse:

```ruby
db.import_bundle("a_bundle_my_peer_gave_me")
```

# Wrapping Up

That's all there is to the protocol spec. In summary:

 * Messages are the core building block of Pigeon databases.
 * Messages can have file attachments via "blobs"
 * Messages can reference other users via "USER.****" multihashes
 * Messages are replicated onto peer machines via "following"
 * Messages can be avoided via "blocking"
 * Messages are shared between machines by passing around a disk directory structure known as a "bundle".
