module ticketland::merkle_tree_test {
  use std::vector;
  use std::hash::sha3_256;
  use ticketland::collection_utils::{compare_vector};

  /// Constants
  const EQUAL: u8 = 2;
  const SMALLER: u8 = 2;

  struct Tree {
    leaves: vector<vector<u8>>,
    root: vector<u8>,
  }
  
  fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
    if (compare_vector(&a, &b) == SMALLER) {
      vector::append(&mut a, b);
      sha3_256(a)
    } else {
      vector::append(&mut b, a);
      sha3_256(b)
    }
  }

  public fun create(leaves: vector<vector<u8>>): Tree {
    let i = 0;
    let origal_leaves = vector[];

    // Copy the entire leaves array
    while(i < vector::length(&leaves)) {
      let item = *vector::borrow(&mut leaves, i);
      vector::push_back(&mut origal_leaves, item);

       i = i + 1;
    };

    let i = 0;
    while (vector::length(&leaves) > 1) {
      // reset if last item reached
      if(i == vector::length(&leaves) - 1) {
        i = 0;
      };

      let left = vector::remove(&mut leaves, i);
      let right = *vector::borrow(&leaves, i + 1);

      // This is how we update the value of vector at a given index
      // 1. Add the new value to the end of the vector
      // 2. Swap it with the index we want to update
      // 3. Delete the last time which will be the old value
      let last_item_index = vector::length(&leaves);
      vector::push_back(&mut leaves, hash_pair(left, right));
      vector::swap(&mut leaves, i, last_item_index);
      vector::pop_back(&mut leaves);

      i = i + 1;
    };

    Tree {
      leaves: origal_leaves,
      root: vector::remove(&mut leaves, 0),
    }
  }
}
