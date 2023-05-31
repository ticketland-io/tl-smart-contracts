// #[test_only]
// module ticketland::fixed_price_sale_test {
//   use sui::clock::{Self, Clock, increment_for_testing};
//   use std::string::{utf8};
//   use sui::coin::{Self, Coin, mint_for_testing, burn_for_testing};
//   // use sui::sui::SUI;
//   use sui::test_scenario::{
//     Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
//     take_shared, return_shared, take_from_address,
//   };
//   use ticketland::merkle_tree_test::{Tree, get_proof};
//   use ticketland::usdc::{USDC};
//   use ticketland::ticket::{CNT};
//   use ticketland::event_test::{create_new_event, setup_ticket_types};
//   use ticketland::event::{Event, EventOrganizerCap, test_init};
//   use ticketland::primary_market::{refundable};
//   use ticketland::common_test::{to_base};

//   fun setup(scenario: &mut Scenario, clock: &Clock): (Event, Tree) {
//     test_init(ctx(scenario));
//     create_new_event(scenario);
//     next_tx(scenario, @admin);
//     let event = take_shared<Event>(scenario);
//     let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    
//     let (_, tree_3, _) = setup_ticket_types(
//       scenario,
//       &organizer_cap,
//       clock,
//       &mut event,
//     );
    
//     next_tx(scenario, @admin);
//     return_to_sender(scenario, organizer_cap);

//     (event, tree_2)
//   }

//   fun refundable_purchase(buyer: address) {
//     let scenario = test_scenario::begin(@admin);
//     let clock = clock::create_for_testing(ctx(&mut scenario));
//     let (event, tree_2) = setup(&mut scenario, &clock);
//     let scenario_buyer = test_scenario::begin(buyer);
//     let proof = get_proof(&tree_2, 25);
//     increment_for_testing(&mut clock, 10);
//     let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
//     next_tx(&mut scenario_buyer, buyer);

//     refundable(
//       &mut event,
//       &mut usdc_coins,
//       1,
//       utf8(b"Paid Ticket"),
//       25,
//       utf8(b"25"),
//       proof,
//       &clock,
//       ctx(&mut scenario_buyer),
//     );
    
//     next_tx(&mut scenario_buyer, buyer);

//     // CNT object is created and sent to the buyer
//     let cnt = take_from_sender<CNT>(&mut scenario_buyer);

//     // Fees should be sent to protocol recipient 5% of 100 USDC price
//     let coins = take_from_address<Coin<USDC>>(&mut scenario_buyer, @protocol_fee_address);
//     assert!(coin::value(&coins) == to_base(5), 1);
//     burn_for_testing(coins);

//     // Price minus fees should be sent to the event organizer (in our case it's admin)
//     let coins = take_from_address<Coin<USDC>>(&mut scenario_buyer, @admin);
//     assert!(coin::value(&coins) == to_base(95), 1);
//     burn_for_testing(coins);

//     drop_config(config);
//     return_shared(event);
//     return_to_sender(&mut scenario_buyer, cnt);
//     burn_for_testing(usdc_coins);
//     clock::destroy_for_testing(clock);
//     end(scenario);
//     end(scenario_buyer);
//   }
// }
