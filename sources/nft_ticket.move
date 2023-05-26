module ticketland::nft_ticket {
  use sui::package;
  use sui::display;
  use sui::address;
  use std::vector;
  use sui::object::{Self, UID, ID};
  use sui::transfer::{transfer, public_transfer, share_object};
  use sui::tx_context::{TxContext, sender};
  use std::string::{utf8, String};
  use sui::vec_map::{Self, VecMap};
  use sui::bag::{Self, Bag};
  use ticketland::event::{
    Self, Event, EventOrganizerCap, event_organizer_cap_into_event_id, is_event_ticket_type,
  };

  friend ticketland::primary_market;

  /// One-Time-Witness for the module.
  struct NFT_TICKET has drop {}

  /// A registrys NftTicketDetails that are used to utlimately mint new NftTickets
  struct NftRepository has key {
    id: UID,
    // event id (as address) => ticket_type_id => NftTicketDetails
    ticket_nfts: VecMap<address, VecMap<address, NftTicketDetails>>,
  }

  // A struct that contains the details of each NFT an event organizer issues and which can later be 
  // claimed by Ticket holders and which will mint and attach a new NftTicket
  struct NftTicketDetails has store, drop {
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

  /// Errros
  const E_PROPERTY_VEC_MISMATCH: u64 = 0;
  const E_WRONG_TICKET_TYPE: u64 = 1;

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

    let nft_repository = NftRepository {
      id: object::new(ctx),
      ticket_nfts: vec_map::empty(),
    };

    public_transfer(publisher, sender(ctx));
    public_transfer(d1, sender(ctx));
    public_transfer(d2, sender(ctx));
    share_object(nft_repository);
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

  public entry fun register_nft_ticket(
    event: &Event,
    cap: &EventOrganizerCap,
    nft_repository: &mut NftRepository,
    event_id: address,
    ticket_type_id: address,
    name: String,
    description: String,
    image_uri: String,
    property_keys: vector<String>,
    property_values: vector<String>,
  ) {
    assert!(is_event_ticket_type(event, ticket_type_id), E_WRONG_TICKET_TYPE);
    let len = vector::length(&property_keys);
    assert!(len == vector::length(&property_values), E_PROPERTY_VEC_MISMATCH);
    let event_id = event_organizer_cap_into_event_id(cap);
    let properties = vec_map::empty<String, String>();
    let i = 0;

    while (i < len) {
      let key = vector::pop_back(&mut property_keys);
      let val = vector::pop_back(&mut property_values);
      
      vec_map::insert(&mut properties, key, val);
      i = i + 1;
    };

    let nft_details = NftTicketDetails {
      name,
      description,
      image_uri,
      properties,
    };

    // store the nft details. Initialize the nested vec maps if needed
    if(vec_map::contains(&nft_repository.ticket_nfts, &event_id)) {
      let nested_map = vec_map::get_mut(&mut nft_repository.ticket_nfts, &event_id);

      // create nested vec_map if needed
      if(vec_map::contains(nested_map, &ticket_type_id)) {
        // remove the old one and replace with the new
        vec_map::remove(nested_map, &ticket_type_id);
        vec_map::insert(nested_map, ticket_type_id, nft_details);
      } else {
        vec_map::insert(nested_map, ticket_type_id, nft_details);
      }
    } else {
      vec_map::insert(&mut nft_repository.ticket_nfts, event_id, vec_map::empty());
      let nested_map = vec_map::get_mut(&mut nft_repository.ticket_nfts, &event_id);
      vec_map::insert(nested_map, ticket_type_id, nft_details);
    }
  }
}
