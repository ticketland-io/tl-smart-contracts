// #[test_only]
// module ticketland::primary_market_test {
//   use sui::clock::{Self};
//   use sui::test_scenario::{
//     Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
//     take_shared, return_shared,
//   };
//   use ticketland::event_test::{create_new_event, setup_ticket_types};
//   use ticketland::event::{Event, EventOrganizerCap, test_init};

//   fun setup(scenario: &mut Scenario) {
//     test_init(ctx(scenario));
//     create_new_event(scenario, @admin);
//     next_tx(scenario, @admin);

//     let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
//     let event = take_shared<Event>(scenario);
//     let clock = clock::create_for_testing(ctx(scenario));

//     setup_ticket_types(
//       scenario,
//       &organizer_cap,
//       &mut clock,
//       &mut event,
//       @admin,
//       @protocol_fee_address,
//       @operator_1,
//       @operator_2,
//     );
//     next_tx(scenario, @admin);
//   }


//   #[test]
//   fun test_free_sale() {

//   }
// }
