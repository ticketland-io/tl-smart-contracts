module ticketland::nft_ticket {
  use sui::package;
  use sui::display;
  use sui::address;
  use sui::object::{Self, UID, ID};
  use sui::transfer::{transfer, public_transfer};
  use sui::tx_context::{TxContext, sender};
  use std::string::{utf8, String};
  use sui::vec_map::{Self, VecMap};
  use sui::bag::{Self, Bag};

  friend ticketland::primary_market;

  /// One-Time-Witness for the module.
  struct NFT_TICKET has drop {}

  struct Config has key {
    id: UID,
    // event id => ticket_type_id => NftTicketDetails
    properties: VecMap<String, VecMap<ID, NftTicketDetails>>,
  }
  
  // A struct that contains the details of each NFT an event organizer issues and which can later be 
  // claimed by Ticket holders and which will mint and attach a new NftTicket
  struct NftTicketDetails has store {
    name: String,
    description: String,
    image_uri: String,
    properties: VecMap<String, String>,
  }

  struct NftTicket has key {
    id: UID,
    /// The name of the NFT
    name: String,
    /// The description of the NFT
    description: String,
    /// The image uri
    image_uri: String,
    /// Custom metadata attributes
    properties: VecMap<String, String>,
  }

  // This is the core Ticket. It's a compound NFT meaming that it consists of everal other NftTicket attached to it.
  struct Ticket has key {
    id: UID,
    /// Internal off-chain event id
    event_id: String,
    /// The name of the ticket
    name: String,
    /// The price this ticket was sold for
    price_sold: u256,
    /// Seat Index
    seat_index: String,
    /// The seat name
    seat_name: String,
    /// All attached NFT tickets
    attached_nfts: Bag,
  }

  fun init(otw: NFT_TICKET, ctx: &mut TxContext) {
    let ticket_keys = vector[
      utf8(b"Event id"),
      utf8(b"Name"),
      utf8(b"Link"),
      utf8(b"Price"),
      utf8(b"Seat Index"),
      utf8(b"Seat Name"),
    ];

    let ticket_values = vector[
      utf8(b"{name}"),
      utf8(b"{event_id}"),
      utf8(b"https://app.ticketland/events/{event_id}"),
      utf8(b"{price_sold}"),
      utf8(b"{seat_index}"),
      utf8(b"{seat_name}"),
    ];

    let nft_keys = vector[
      utf8(b"Name"),
      utf8(b"Description"),
      utf8(b"Image Uri"),
    ];

    let nft_values = vector[
      utf8(b"{name}"),
      utf8(b"{description}"),
      utf8(b"{image_uri}"),
    ];

    let publisher = package::claim(otw, ctx);
    let d1 = display::new_with_fields<Ticket>(&publisher, ticket_keys, ticket_values, ctx);
    let d2 = display::new_with_fields<NftTicket>(&publisher, nft_keys, nft_values, ctx);

    // Commit first version of `Display` to apply changes.
    display::update_version(&mut d1);
    display::update_version(&mut d2);

    public_transfer(publisher, sender(ctx));
    public_transfer(d1, sender(ctx));
    public_transfer(d2, sender(ctx));
  }

  /// Mints the root Ticket Object
  public(friend) fun mint_ticket(
    event_id: String,
    name: String,
    seat_index: String,
    seat_name: String,
    price_sold: u256,
    ctx: &mut TxContext,
  ): Ticket {
    Ticket {
      id: object::new(ctx),
      event_id,
      name,
      seat_index,
      seat_name,
      price_sold,
      attached_nfts: bag::new(ctx),
    }
  }
}
