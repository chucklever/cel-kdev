# AIO drgn patterns

## Ring buffer state

```python
from drgn import Object, cast
from drgn.helpers.linux.mm import page_to_virt

ring_folio = ctx.ring_folios[0]
page = cast('struct page *', ring_folio)
virt = page_to_virt(page).value_()
ring = Object(prog, 'struct aio_ring', address=virt)
print(f"head={ring.head} tail={ring.tail} nr={ring.nr}")
avail = (ring.tail.value_() - ring.head.value_()) % ring.nr.value_()
print(f"events available: {avail}")
```

## Slot accounting

`reqs_available` is initialized to `nr_events - 1`, not
`max_reqs`. The invariant:

    atomic + sum(per_cpu) + ring_events + in_flight = nr_events - 1
