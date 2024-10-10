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


new_poly_data :: proc($T: typeid, name: string) -> Event(T)
{
    return Event(T) {
        name = name,
        subs = {},
    }
}

new_no_data :: proc(name: string) -> Event(None)
{
    return Event(None) {
        name = name,
        subs = {},
    }
}

signal_no_data :: proc(event: ^Event(None))
{
    log.debug("Signaling event", event.name)
    subs := list.iterator_head(event.subs, EventSub(None), "node")
    for sub in list.iterate_next(&subs) {
        sub.cb.(proc())()
    }
}

signal_poly_data :: proc(event: ^Event($T), data: T)
{
    log.debug("Signaling event", event.name)
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
        @(static) subscriber: EventSub(T) = {}
        listen(e, &subscriber, cb)
    }
    e := new(^int, "test")
    defer clear(&e)
    es := EventSub(^int){}
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
        x = 10
    })
    
    signal(&e)

    testing.expect(t, x == 10)
}

