#[test_only]
module ticketland::merkle_tree_test {
  use std::vector;
  use std::hash::sha3_256;
  use std::string::{Self, utf8, bytes};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::collection_utils::{compare_vector};

  /// Constants
  const EQUAL: u8 = 2;
  const SMALLER: u8 = 2;

  struct Tree has drop {
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

  public fun root(tree: &Tree): &vector<u8> {
    &tree.root
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
      if(i == vector::length(&leaves) - 1 || i == vector::length(&leaves)) {
        i = 0;
      };

      let left = vector::remove(&mut leaves, i);
      let right = *vector::borrow(&leaves, i);

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

  /// Create a sparse merkle tree
  /// 
  /// # Arguments
  /// 
  /// * `total_tickets` Total number of leaves
  /// * `start_index` The start index of the range that will Non-Null have values
  /// * `end_index` The end index of the range that will Non-Null have values
  public fun create_tree(total_tickets: u64, start_index: u64, end_index: u64): Tree {
    let leaves = vector[];
    let i = 0;

    while(i < total_tickets) {
      if(i >= start_index && i <= end_index) {
        let seat_index = u64_to_str(i);
        let seat_name = u64_to_str(i);

        string::append(&mut seat_index, utf8(b"."));
        string::append(&mut seat_index, seat_name);

        vector::push_back(&mut leaves, *bytes(&seat_index));
      } else {
        vector::push_back(&mut leaves, b"NULL");
      };

      i = i + 1;
    };

    create(leaves)
  }
}
