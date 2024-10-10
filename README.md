# Events in Odin
This is a simple event handling implementation for Odin.

# Features
- Static or dynamic allocations
- Events with or without data
- Very simple interface

# Example
```Odin
package main

import ev "event"

main :: proc()
{
    @static x := 0

    // Create event with and without data
    my_event_with_data := new(^int, "Event With Data")
    my_event_without_data := new("Event Without Data")
    
    // All dynamic allocations can be freed using clear
    defer clear(&my_event_with_data)
    defer clear(&my_event_without_data)

    // Add dynamically allocated listener
    ev.listen(&my_event_with_data, proc(x_ptr: ^int) {
        x_ptr^ += 1
    })
    ev.listen(&my_event_without_data, proc() {
        x += 1
    })

    // Add statically allocated listener
    ev_sub_with_data := ev.new_sub(^int)
    ev.listen(&my_event_with_data, &ev_sub_with_data, proc(x_ptr: ^int) {
        x_ptr^ += 1
    })

    ev_sub_without_data := ev.new_sub()
    ev.listen(&my_event_without_data, &ev_sub_without_data, proc() {
        x += 1
    })

    // When declaring @static event subscribers, the following equivalents can be used
    @static static_ev_sub_with_data := ev.EventSub(^int){}
    @static static_ev_sub_without_Data := ev.EventSub(ev.None){}  // the ev.None distinct type marks no data for event


    //  Signalling events
    ev.signal(&my_event_with_data, &x)
    assert(x == 2)
    ev.signal(&my_event_without_data)
    assert(x == 4)
}

```
