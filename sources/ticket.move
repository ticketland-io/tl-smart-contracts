module ticketland::ticket {
  use sui::package;
  use sui::display;
  use std::vector;
  use sui::object::{Self, UID, uid_to_address};
  use sui::transfer::{Self, public_transfer, share_object};
  use sui::tx_context::{TxContext, sender};
  use std::string::{utf8, String};
  use sui::vec_map::{Self, VecMap};
  use sui::object_bag::{Self, ObjectBag};
  use ticketland::event::{
    Event, EventOrganizerCap, get_event_organizer_cap_event_id, is_event_ticket_type,
  };

  friend ticketland::basic_sale;
  friend ticketland::attendance;

  /// constants
  const MAX_NFT_PER_TICKET_TYPE: u64 = 10;

  /// Errros
  const E_PROPERTY_VEC_MISMATCH: u64 = 0;
  const E_WRONG_TICKET_TYPE: u64 = 1;
  const E_WRONG_EVENT: u64 = 2;
  const E_NOT_EVENT_TICKET_TYPE: u64 = 3;

  /// One-Time-Witness for the module.
  struct TICKET has drop {}

  /// A registrys NftTicketDetails that are used to utlimately mint new NftTickets
  struct NftRepository has key {
    id: UID,
    // event id (as address) => ticket_type_id => nft_ref_name => NftTicketDetails
    // Each ticket type in an event can have multiple claimable NFTs. For example, a VIP ticket
    // type might have a pre-event NFT which Ticket holders can claim, but a rgular ticket might not.
    nfts_per_ticket_type: VecMap<address, VecMap<address, VecMap<String, NftTicketDetails>>>,

    // A list of airdrops claimable by any event ticket holder regardless of ticket type.
    // We could, in theory, use `nfts_per_ticket_type` collection but it would require duplications; so for
    // performance reasons we better maintain a separate collection.
    nfts_per_event: VecMap<address, VecMap<String, NftTicketDetails>>,
  }

  // A struct that contains the details of each NFT an event organizer issues and which can later be 
  // claimed by Ticket holders and which will mint and attach a new NftTicket
  struct NftTicketDetails has store, copy, drop {
    name: String,
    description: String,
    image_uri: String,
    properties: VecMap<String, String>,
  }

  struct NftTicket has key, store {
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

  // This is the core Compound NFT Ticket Object. It's a compound NFT meaming that it consists of everal
  // other NftTicket attached to it.
  struct CNT has key {
    id: UID,
    /// The on-chain id of the event (as address)
    event_id: address,
    /// The CNT type id (as address)
    ticket_type_id: address,
    /// The off-chain event id
    e_id: String,
    /// The name of the CNT
    name: String,
    /// The price this CNT was sold for
    price_sold: u64,
    /// Seat Index
    seat_index: String,
    /// The seat name
    seat_name: String,
    /// indicates if the owner has attended the event
    attended: bool,
    /// All attached NFT tickets
    attached_nfts: ObjectBag,
  }

  fun init(otw: TICKET, ctx: &mut TxContext) {
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
      utf8(b"{e_id}"),
      utf8(b"https://app.ticketland/events/{e_id}"),
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
    let d1 = display::new_with_fields<CNT>(&publisher, ticket_keys, ticket_values, ctx);
    let d2 = display::new_with_fields<NftTicket>(&publisher, nft_keys, nft_values, ctx);

    // Commit first version of `Display` to apply changes.
    display::update_version(&mut d1);
    display::update_version(&mut d2);

    let nft_repository = NftRepository {
      id: object::new(ctx),
      nfts_per_ticket_type: vec_map::empty(),
      nfts_per_event: vec_map::empty(),
    };

    public_transfer(publisher, sender(ctx));
    public_transfer(d1, sender(ctx));
    public_transfer(d2, sender(ctx));
    share_object(nft_repository);
  }

  public fun get_cnt_id(cnt: &CNT): address {
    uid_to_address(&cnt.id)
  }

  public fun get_cnt_event_id(cnt: &CNT): address {
    cnt.event_id
  }

  /// It will make sure that all VecMaps until the most inner one have been initialized.
  /// Once this function is called, all the caller has to check is that the `nft_ref_name => NftTicketDetails`
  /// part exist and if not insert a value. This function makes sure that the `event id (as address) => ticket_type_id =>`
  /// will be setup so it is safe to safely use the VecMap's get and get_mut API.
  /// Finally, the function will return the inner most part `nft_ref_name => NftTicketDetails` so it can be consumed.
  fun init_nfts_per_ticket_type(
    event_id: address,
    ticket_type_id: address,
    nft_repository: &mut NftRepository,
  ): &mut VecMap<String, NftTicketDetails> {
    // Init all nested VecMaps where needed
    if(vec_map::contains(&nft_repository.nfts_per_ticket_type, &event_id)) {
      let l2_map = vec_map::get_mut(&mut nft_repository.nfts_per_ticket_type, &event_id);

      if(!vec_map::contains(l2_map, &ticket_type_id)) {
        vec_map::insert(l2_map, ticket_type_id, vec_map::empty());
      };

      vec_map::get_mut(
        vec_map::get_mut(&mut nft_repository.nfts_per_ticket_type, &event_id),
        &ticket_type_id,
      )
    } else {
      let l2_map = vec_map::empty();
      vec_map::insert(&mut l2_map, ticket_type_id, vec_map::empty());
      vec_map::insert(&mut nft_repository.nfts_per_ticket_type, event_id, l2_map);

      vec_map::get_mut(
        vec_map::get_mut(&mut nft_repository.nfts_per_ticket_type, &event_id),
        &ticket_type_id,
      )
    }
  }

  /// Similar in logic to `init_nfts_per_ticket_type`
  fun init_nfts_per_event(
    event_id: address,
    nft_repository: &mut NftRepository,
  ): &mut VecMap<String, NftTicketDetails> {
    if(vec_map::contains(&nft_repository.nfts_per_event, &event_id)) {
      vec_map::get_mut(&mut nft_repository.nfts_per_event, &event_id)
    } else {
      vec_map::insert(&mut nft_repository.nfts_per_event, event_id, vec_map::empty());
      vec_map::get_mut(&mut nft_repository.nfts_per_event, &event_id)
    }
  }

  /// Internal function that will create a new NftTicketDetails
  fun create_nft_details(
    name: String,
    description: String,
    image_uri: String,
    property_keys: vector<String>,
    property_values: vector<String>,
    cap: &EventOrganizerCap,
  ): (address, NftTicketDetails) {
    let len = vector::length(&property_keys);
    assert!(len == vector::length(&property_values), E_PROPERTY_VEC_MISMATCH);

    let event_id = get_event_organizer_cap_event_id(cap);
    let properties = vec_map::empty<String, String>();
    let i = 0;

    while (i < len) {
      let key = vector::pop_back(&mut property_keys);
      let val = vector::pop_back(&mut property_values);
      
      vec_map::insert(&mut properties, key, val);
      i = i + 1;
    };

    let nft_detail = NftTicketDetails {
      name,
      description,
      image_uri,
      properties,
    };

    (event_id, nft_detail)
  }

  /// Mints the root CNT Object
  public(friend) fun mint_cnt(
    event_id: address,
    ticket_type_id: address,
    e_id: String,
    name: String,
    seat_index: String,
    seat_name: String,
    price_sold: u64,
    ctx: &mut TxContext,
  ): address {
    let id = object::new(ctx);
    let cnt_id = uid_to_address(&id);

    let cnt = CNT {
      id,
      event_id,
      ticket_type_id,
      e_id,
      name,
      seat_index,
      seat_name,
      price_sold,
      attended: false,
      attached_nfts: object_bag::new(ctx),
    };

    transfer::transfer(cnt, sender(ctx));

    cnt_id
  }

  /// Allows the event organizer to register new (or update existing) Ticket NFT descriptions. Any arbitraty number
  /// of such NFTS can be created. Once description added, CNT object owners can claim a new NFT in a subsequent call.
  /// It will fail if `nft_ref_name` has been already registered
  /// 
  /// # Arguments
  /// 
  /// * `ticket_type_id` - The id of the TicketType object in address format
  /// * `nft_ref_name` - The reference name of the NFT that is being registered. This is used as a key in VecMap for quick access
  /// * `name` - The NFT name
  /// * `description` - The NFT description
  /// * `image_uri` - The NFT image_uri
  /// * `property_keys` - The NFT property keys
  /// * `property_values` - The NFT property values
  /// * `nft_repository` - The nft repository where the NFT details are stored
  /// * `event` - The Event object for which this NFT is being registered
  /// * `cap` - The capability that gives access to it's bearer to this function
  public entry fun register_nft_ticket_per_ticket_type(
    ticket_type_id: address,
    nft_ref_name: String,
    name: String,
    description: String,
    image_uri: String,
    property_keys: vector<String>,
    property_values: vector<String>,
    nft_repository: &mut NftRepository,
    event: &Event,
    cap: &EventOrganizerCap,
  ) {
    assert!(is_event_ticket_type(event, ticket_type_id), E_NOT_EVENT_TICKET_TYPE);

    let (event_id, nft_details) = create_nft_details(
      name,
      description,
      image_uri,
      property_keys,
      property_values,
      cap,
    );

    let ticket_type_nfts = init_nfts_per_ticket_type(event_id, ticket_type_id, nft_repository);
    vec_map::insert(ticket_type_nfts, nft_ref_name, nft_details);
  }

  /// Similar to `register_nft_ticket_per_ticket_type` but registers claimable NFT for all ticket holder of an event
  public entry fun register_nft_ticket_per_event(
    nft_ref_name: String,
    name: String,
    description: String,
    image_uri: String,
    property_keys: vector<String>,
    property_values: vector<String>,
    nft_repository: &mut NftRepository,
    cap: &EventOrganizerCap,
  ) {
    let (event_id, nft_details) = create_nft_details(
      name,
      description,
      image_uri,
      property_keys,
      property_values,
      cap,
    );

    let event_nfts = init_nfts_per_event(event_id, nft_repository);
    vec_map::insert(event_nfts, nft_ref_name, nft_details);
  }

  /// Creates a new NFT and attaches to the CNT object
  fun create_and_attach_ticket(
    nft_details: &NftTicketDetails,
    cnt: &mut CNT,
    ctx: &mut TxContext,
  ) {
    // Copy the properties vec map
    let properties = vec_map::empty<String, String>();
    let keys = vec_map::keys(&nft_details.properties);
    let len = vector::length(&keys);
    let i = 0;

    while (i < len) {
      let key = vector::borrow(&keys, i);
      vec_map::insert(&mut properties, *key, *vec_map::get(&nft_details.properties, key));
      i = i + 1;
    };

    // create a new NftTicket
    let nft_ticket = NftTicket {
      id: object::new(ctx),
      name: nft_details.name,
      description: nft_details.description,
      image_uri: nft_details.image_uri,
      properties,
    };

    // Attach to the Ticket. Will fail if there's already a cnt with such nft_details attached. This guarantees
    // on ticket claim (for a given ticket type) per each Ticket
    object_bag::add(&mut cnt.attached_nfts, *nft_details, nft_ticket);
  }

  /// Allows the owner of the given Ticket to mint a new NftTicket from the NftRepository.
  /// 
  /// # Arguments
  /// 
  /// * `event_id` - The id of the Event object in address format
  /// * `ticket_type_id` - The id of the TicketType object in address format
  /// * `nft_ref_name` - The reference name of the NFT that is being registered. This is used as a key in VecMap for quick access
  /// * `nft_repository` - The nft repository where the NFT details are stored
  /// * `ticket` - The Ticket object that will get this newly minted NftTicket attached to
  public entry fun mint_nft_ticket_for_ticket_type(
    event_id: address,
    ticket_type_id: address,
    nft_ref_name: String,
    nft_repository: &mut NftRepository,
    cnt: &mut CNT,
    ctx: &mut TxContext,
  ) {
    assert!(cnt.event_id == event_id, E_WRONG_EVENT);
    assert!(cnt.ticket_type_id == ticket_type_id, E_WRONG_TICKET_TYPE);

    let nfts_per_ticket_type = vec_map::get(&nft_repository.nfts_per_ticket_type, &event_id);
    let nft_details = vec_map::get(
      vec_map::get(nfts_per_ticket_type, &ticket_type_id),
      &nft_ref_name,
    );

    create_and_attach_ticket(nft_details, cnt, ctx);
  }

  /// Same as mint_nft_ticket_for_ticket_type but for NFTs claimable on the event level
  public entry fun mint_nft_for_event(
    event_id: address,
    nft_ref_name: String,
    nft_repository: &mut NftRepository,
    cnt: &mut CNT,
    ctx: &mut TxContext,
  ) {
    assert!(cnt.event_id == event_id, E_WRONG_EVENT);

    let nfts_per_event = vec_map::get(&nft_repository.nfts_per_event, &event_id);
    let nft_details = vec_map::get(nfts_per_event, &nft_ref_name,);

    create_and_attach_ticket(nft_details, cnt, ctx);
  }

  public(friend) fun set_attended(cnt: &mut CNT) {
    cnt.attended = true;
  }

  /// Used by friend modules to transfer the given CNT. CNT has not store ability
  /// so any transfer must happen though this module.
  public(friend) fun transfer(cnt: CNT, recipient: address) {
    transfer::transfer(cnt, recipient);
  }
}
