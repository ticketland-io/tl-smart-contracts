// module ticketland::nft_ticket {
//   use sui::package;
//   use sui::display;
//   use sui::object::{Self, UID, ID};
//   use sui::tx_context::{TxContext, sender};
//   use std::string::{utf8, String};
//   use sui::vec_map::{Self, VecMap};

//   /// One-Time-Witness for the module.
//   struct NFT_TICKET has drop {}

//   struct NftTicket has key {
//     id: UID,
//     /// The name of the NFT
//     name: String,
//     /// The description
//     description: String,
//     /// The image uri
//     image_uri: String,
//     /// Custom metadata attributes
//     properties: VecMap<String, String>
//   }

//   fun init(otw: NFT_TICKET, ctx: &mut TxContext) {
//     let creator = sender(ctx);

//     let event_nft_keys = vector[
//       utf8(b"name"),
//       utf8(b"description"),
//       utf8(b"image_uri"),
//       utf8(b"link"),
//       utf8(b"creator"),
//     ];

//     let event_nft_values = vector[
//       utf8(b"{name}"),
//       utf8(b"{description}"),
//       utf8(b"{image_uri}"),
//       utf8(b"https://app.ticketland/events/{event_id}"),
//       address::to_string(creator),
//     ];

//     let publisher = package::claim(otw, ctx);
//     let display = display::new_with_fields<NftEvent>(&publisher, event_nft_keys, event_nft_values, ctx);
//     // Commit first version of `Display` to apply changes.
//     display::update_version(&mut display);

//     public_transfer(publisher, sender(ctx));
//     public_transfer(display, sender(ctx));
//   }
// }
