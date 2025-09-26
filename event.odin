package event

import "core:testing"
import "core:log"
import "core:container/intrusive/list"

Event :: struct($T: typeid) {
    name: string,
    subs: list.List,
}

EventCallback :: union($T: typeid) {
    proc(T),
    proc()
}

EventSub :: struct($T: typeid) {
    using node: list.Node,
    cb: EventCallback(T),
    dyn_alloc: bool,
}

None :: distinct struct {}



new :: proc {new_no_data, new_poly_data}
new_sub :: proc {new_sub_no_data, new_sub_poly_data}
listen :: proc {listen_dynamic, listen_static, listen_dynamic_no_data, listen_static_no_data}
signal :: proc {signal_poly_data, signal_no_data}

clear :: proc(event: ^Event($T))
{
    subs := list.iterator_head(event.subs, EventSub(T), "node")
    for sub in list.iterate_next(&subs) {
        if sub.dyn_alloc {
            free(sub)
        }
    }
}

listen_dynamic_no_data :: proc(event: ^Event(None), cb: proc())
{
    sub := new_clone(EventSub(None) {
        cb = cb,
        dyn_alloc = true,
    })
    list.push_back(&event.subs, sub)
}

listen_static_no_data :: proc(event: ^Event(None), sub: ^EventSub(None), cb: proc())
{
    sub.cb = cb
    sub.dyn_alloc = false
    list.push_back(&event.subs, sub)
}

listen_dynamic :: proc(event: ^Event($T), cb: proc(T))
{
    sub := new_clone(EventSub(T) {
        cb = cb,
        dyn_alloc = true,
    })
    list.push_back(&event.subs, sub)
}

listen_static :: proc(event: ^Event($T), sub: ^EventSub(T), cb: proc(T))
{
    sub.cb = cb
    sub.dyn_alloc = false
    list.push_back(&event.subs, sub)
}

unlisten :: proc(event: ^Event($T), cb: EventCallback(T)) -> (sub: ^EventSub(T), dynamically_allocated: bool)
{
    subs := list.iterator_head(event.subs, EventSub(T), "node")
    for sub in list.iterate_next(&subs) {
        if sub.cb == cb {
            list.remove(&event.subs, transmute(^list.Node)sub)
            return sub, sub.dyn_alloc
        }
    }

    return nil, false
}

new_poly_data :: proc "contextless" ($T: typeid, name: string) -> Event(T)
{
    return Event(T) {
        name = name,
        subs = {},
    }
}

new_no_data :: proc "contextless" (name: string) -> Event(None)
{
    return Event(None) {
        name = name,
        subs = {},
    }
}

new_sub_no_data :: proc() -> EventSub(None)
{
    return {}
}

new_sub_poly_data :: proc($T: typeid) -> EventSub(T)
{
    return {}
}

signal_no_data :: proc(event: ^Event(None))
{
    subs := list.iterator_head(event.subs, EventSub(None), "node")
    for sub in list.iterate_next(&subs) {
        sub.cb.(proc())()
    }
}

signal_poly_data :: proc(event: ^Event($T), data: T)
{
    subs := list.iterator_head(event.subs, EventSub(T), "node")
    for sub in list.iterate_next(&subs) {
        sub.cb.(proc(T))(data)
    }
}

@(test)
test_new :: proc(t: ^testing.T)
{
    e := new(int, "test")
    testing.expect(t, e.name == "test")
}

@(test)
test_listen :: proc(t: ^testing.T)
{
    sub :: proc(e: ^Event($T), cb: proc(T))
    {
        @(static) subscriber := EventSub(T){}
        listen(e, &subscriber, cb)
    }
    e := new(^int, "test")
    defer clear(&e)
    es := new_sub(^int)
    x := 0

    signal(&e, &x)

    testing.expect(t, x == 0)

    sub(&e, proc(i: ^int) { i^ += 1  })
    listen(&e, &es, proc(i: ^int) { i^ += 2 })


    signal(&e, &x)

    testing.expect(t, x == 3)
}

@(test)
test_listen_no_data :: proc(t: ^testing.T)
{
    @static x := 0
    e := new("Test")
    defer clear(&e)

    listen(&e, proc() {
        x += 10
    })

    ev_sub0 := new_sub()
    ev_sub1 := EventSub(None){}

    listen(&e, &ev_sub0, proc() {
        x += 5
    })

    listen(&e, &ev_sub1, proc() {
        x += 5
    })
    
    signal(&e)

    testing.expect(t, x == 20)
}

@(test)
test_readme_code :: proc(t: ^testing.T)
{
    @static x := 0

    // Create event with and without data
    my_event_with_data := new(^int, "Event With Data")
    defer clear(&my_event_with_data)
    my_event_without_data := new("Event Without Data")
    defer clear(&my_event_without_data)

    // Add dynamically allocated listener
    listen(&my_event_with_data, proc(x_ptr: ^int) {
        x_ptr^ += 1
    })
    listen(&my_event_without_data, proc() {
        x += 1
    })

    // Add statically allocated listener
    ev_sub_with_data := new_sub(^int)
    listen(&my_event_with_data, &ev_sub_with_data, proc(x_ptr: ^int) {
        x_ptr^ += 1
    })

    ev_sub_without_data := new_sub()
    listen(&my_event_without_data, &ev_sub_without_data, proc() {
        x += 1
    })

    // When declaring @static event subscribers, the following equivalents can be used
    @static static_ev_sub_with_data := EventSub(^int){}
    @static static_ev_sub_without_Data := EventSub(None){}  // the ev.None distinct type marks no data for event

    double :: proc(x_ptr: ^int) {
        x_ptr^ *= 2
    }
    make_big :: proc() {
        x *= 200
    }   
    listen(&my_event_with_data, &static_ev_sub_with_data, double)
    listen(&my_event_without_data, &static_ev_sub_without_Data, make_big)

    // Listeners can be removed dynamically
    unlisten(&my_event_with_data, double)
    unlisten(&my_event_without_data, make_big)

    // unlisten does not free subscribers it self, the user can check the return
    // value of the function to determine if the value should be freed or not
    listen(&my_event_without_data, make_big)
    if mysub, dyn_allocced := unlisten(&my_event_without_data, make_big); dyn_allocced {
        free(mysub)
    }

    //  Signalling events
    signal(&my_event_with_data, &x)
    assert(x == 2)
    signal(&my_event_without_data)
    assert(x == 4)
}
