package event

import "core:testing"
import "core:container/intrusive/list"

Event :: struct($T: typeid) {
    name: string,
    subs: list.List,
}

EventSub :: struct($T: typeid) {
    using node: list.Node,
    cb: proc(T),
}

listen :: proc {listen_dynamic, listen_static}


listen_dynamic :: proc(event: ^Event($T), cb: proc(T))
{
    sub := new_clone(EventSub(T) {
        cb = cb,
    })
    list.push_front(&event.subs, sub)
}

listen_static :: proc(event: ^Event($T), sub: ^EventSub(T), cb: proc(T))
{
    sub.cb = cb
    list.push_front(&event.subs, sub)
}


new :: proc($T: typeid, name: string) -> Event(T)
{
    return Event(T) {
        name = name,
        subs = {},
    }
}

signal :: proc(event: ^Event($T), data: T)
{
    ok := true
    for sub := event.subs.head; sub != nil; sub = sub.next {
        evsub := container_of(sub, EventSub(T), "node")
        evsub.cb(data)
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
    es := EventSub(^int){}
    x := 0

    signal(&e, &x)

    testing.expect(t, x == 0)

    sub(&e, proc(i: ^int) { i^ += 1  })
    listen(&e, &es, proc(i: ^int) { i^ += 2 })


    signal(&e, &x)

    testing.expect(t, x == 3)
}


