# V114 Live State Fix

- Host exit confirmation; viewer exit never ends the room.
- Persistent tap/gift counters survive leaving/re-entry.
- Live comments can be pinned with server-side expiry: 30s, 1m, 5m, 30m, or no expiry.
- Pinned comment renders in a fixed rail above scrolling comments.
- Pin state and expiry are broadcast over Socket.IO and restored from API.
