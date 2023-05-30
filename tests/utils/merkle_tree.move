#[test_only]
module ticketland::merkle_tree_test {
  use std::vector;
  use std::hash::sha3_256;
  use std::string::{Self, utf8, bytes};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::collection_utils::{compare_vector};

  /// Constants
  const EQUAL: u8 = 0;
  const SMALLER: u8 = 1;
  const EMPTY: vector<u8> = b"";

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

  fun one_level_up(layer: &mut vector<vector<u8>>): vector<vector<u8>> {
    let len = vector::length(layer);
    // if odd then add one more value to make the number event
    if(len % 2 == 1) {
      vector::push_back(layer, EMPTY);
    };

    let result = vector[];
    let i = 0;

    while(i < len) {
      let left = *vector::borrow(layer, i);
      let right = *vector::borrow(layer, i + 1);

      vector::push_back(&mut result, hash_pair(left, right));
      i = i + 2;
    };

    result
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

    while (vector::length(&leaves) > 1) {
      leaves = one_level_up(&mut leaves);
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
