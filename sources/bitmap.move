module ticketland::bitmap {
  use std::vector;

  struct Bitmap has store {
    inner: vector<u8>,
  }

  fun index_to_byte_and_bit(index: u64): (u64, u8, u8) {
    let byte = index / 8;
    let bit = (index - (byte * 8) as u8); // instead of using module index % 8
    let mask = 1 << bit;

    (byte, bit, mask)
  }

  public fun is_set(index: u64, bitmap: &Bitmap): bool {
    let (byte, bit, _) = index_to_byte_and_bit(index);
    let value = *vector::borrow(&bitmap.inner, byte);

    (value >> bit) % 2 == 1
  }

  public fun flip_bit(index: u64, bitmap: &mut Bitmap) {
    let (byte, _, mask) = index_to_byte_and_bit(index);
    let cur_val = *vector::borrow(&bitmap.inner, byte);

    // This is how we update the value of vector at a given index
    // 1. Add the new value to the end of the vector
    // 2. Swap it with the index we want to update
    // 3. Delete the last time which will be the old value
    let last_item_index = vector::length(&bitmap.inner);
    vector::push_back(&mut bitmap.inner, ((cur_val ^ mask) as u8));
    vector::swap(&mut bitmap.inner, byte, last_item_index);
    vector::pop_back(&mut bitmap.inner);
  }
}
