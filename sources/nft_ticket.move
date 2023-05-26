module ticketland::nft_ticket {
  use sui::package;
  use sui::display;
  use sui::address;
  use sui::object::{Self, UID, ID};
  use sui::transfer::{transfer, public_transfer};
  use sui::tx_context::{TxContext, sender};
  use std::string::{utf8, String};
  use sui::vec_map::{Self, VecMap};

  friend ticketland::primary_market;

  /// One-Time-Witness for the module.
  struct NFT_TICKET has drop {}

  struct NftTicket has key {
    id: UID,
    /// Internal off-chain event id
    event_id: String,
    /// The name of the NFT
    name: String,
    /// The image uri
    image_uri: String,
    /// Custom metadata attributes
    properties: VecMap<String, String>,
    /// The price this NFT was sold for
    price_sold: u256,
  }

  fun init(otw: NFT_TICKET, ctx: &mut TxContext) {
    let creator = sender(ctx);

    let nft_keys = vector[
      utf8(b"Event id"),
      utf8(b"Name"),
      utf8(b"Image Uri"),
      utf8(b"Link"),
      utf8(b"Creator"),
    ];

    let nft_values = vector[
      utf8(b"{name}"),
      utf8(b"{event_id}"),
      utf8(b"{image_uri}"),
      utf8(b"https://app.ticketland/events/{event_id}"),
      address::to_string(creator),
    ];

    let publisher = package::claim(otw, ctx);
    let display = display::new_with_fields<NftTicket>(&publisher, nft_keys, nft_values, ctx);
    // Commit first version of `Display` to apply changes.
    display::update_version(&mut display);

    public_transfer(publisher, sender(ctx));
    public_transfer(display, sender(ctx));
  }

  public(friend) fun create_ticket(
    event_id: String,
    name: String,
    image_uri: String,
    price_sold: u256,
    ctx: &mut TxContext,
  ): NftTicket {
    NftTicket {
      id: object::new(ctx),
      event_id,
      name,
      image_uri,
      price_sold,
      // We add this to make it future proof. We might want to add additional custom metadata
      // attributes to each event NFT in the future. So to make module upgrades compatible, we
      // want to have this field in the struct
      properties: vec_map::empty(),
    }
  }
}
