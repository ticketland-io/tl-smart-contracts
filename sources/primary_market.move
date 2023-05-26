module ticketland::primary_market {
  use sui::object::{Self, UID, ID};
  use ticketland::event::{Event};

  public entry fun free_sale(
    event: &Event,
    seat_index: u32,
    seat_name: String,
    ctx: Context
  ) {
    // 1. pre-checks: Verify the seat using merkle path verification
    // 2. Create a new ticket
    // 3. post-checks: update event capacity bitmap and other relevant fields
  }
}
