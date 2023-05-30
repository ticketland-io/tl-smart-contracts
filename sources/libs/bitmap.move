module ticketland::bitmap {
  use sui::tx_context::{TxContext};
  use sui::table::{Self, Table};

  struct Bitmap has store {
    /// We can't use vector since it's not a fixed size array. That means that reading an index that does not have a value
    /// will abort. In addition, we can't just insert at random indexes in vector; it has to be sequential.
    inner: Table<u64, u8>,
  }

  public fun empty(ctx: &mut TxContext): Bitmap {
    Bitmap {
      inner: table::new(ctx),
    }
  }

  fun index_to_byte_and_bit(index: u64): (u64, u8, u8) {
    let byte = index / 8;
    let bit = (index - (byte * 8) as u8); // instead of using module index % 8
    let mask = 1 << bit;

    (byte, bit, mask)
  }

  fun get(bitmap: &Bitmap, index: u64): u8 {
    // return default 0 by default
    if(table::contains(&bitmap.inner, index)) {
      *table::borrow(&bitmap.inner, index)
    } else {
      0
    }
  }

  fun get_mut(bitmap: &mut Bitmap, index: u64): &mut u8 {
    // add default 0 is key doesn't exist
    if(!table::contains(&bitmap.inner, index)) {
      table::add(&mut bitmap.inner, index, 0)
    };

    table::borrow_mut(&mut bitmap.inner, index)
  }

  public fun is_set(bitmap: &Bitmap, index: u64): bool {
    let (byte, bit, _) = index_to_byte_and_bit(index);
    let value = get(bitmap, byte);

    (value >> bit) % 2 == 1
  }

  public fun flip_bit(bitmap: &mut Bitmap, index: u64) {
    let (byte, _, mask) = index_to_byte_and_bit(index);
    let cur_val = get_mut(bitmap, byte);
    let new_val = ((*cur_val ^ mask) as u8);
    *cur_val = new_val;
  }
}
