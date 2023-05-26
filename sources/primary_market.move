module ticketland::primary_market {
  use sui::object::{Self, UID, ID};
  use std::vector;
  use sui::tx_context::{TxContext};
  use std::string::{Self, String};
  use ticketland::event::{Event};
  use ticketland::num_utils::{u32_to_str};

  fun create_seat_leaf(seat_index: u32, seat_name: String): vector<u8> {
    let p1 = *string::bytes(&u32_to_str(seat_index));
    let p2 = b".";
    let p3 = string::bytes(&seat_name);
    
    vector::append(&mut p1, p2);
    vector::append(&mut p1, *p3);

    p1
  }

  public entry fun free_sale(
    event: &Event,
    seat_index: u32,
    seat_name: String,
    ctx: &mut TxContext
  ) {
    // 1. pre-checks: Verify the seat using merkle path verification
    // 2. Create a new ticket
    // 3. post-checks: update event capacity bitmap and other relevant fields
  }
}
