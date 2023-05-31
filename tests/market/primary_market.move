#[test_only]
module ticketland::primary_market_test {
  use sui::clock::{Self, Clock};
  use sui::test_scenario::{
    Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::event_test::{create_new_event, setup_ticket_types};
  use ticketland::event::{Event, EventOrganizerCap, test_init};

  fun setup(scenario: &mut Scenario, clock: &Clock) {
    test_init(ctx(scenario));
    create_new_event(scenario);
    next_tx(scenario, @admin);

    let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    let event = take_shared<Event>(scenario);
    
    setup_ticket_types(
      scenario,
      &organizer_cap,
      clock,
      &mut event,
    );

    next_tx(scenario, @admin);

    return_to_sender(scenario, organizer_cap);
    return_shared(event);
  }


  #[test]
  fun test_free_sale() {
    let scenario = test_scenario::begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    setup(&mut scenario, &clock);

    clock::destroy_for_testing(clock);
    end(scenario);
  }
}
