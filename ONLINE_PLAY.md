# Online Play Setup

This prototype supports a room-code host/join flow through a tiny local room server exposed with Cloudflare Quick Tunnels.

## One-time setup

Install Cloudflare's tunnel tool:

```bash
brew install cloudflared
```

## Start the online room service

From the project folder:

```bash
cd /Users/chris/Dev/Godot/TestGame/darkvael
chmod +x tools/start_online_tunnel.sh
./tools/start_online_tunnel.sh
```

That script:

1. starts the local Python room server on `127.0.0.1:8787`
2. opens a Cloudflare Quick Tunnel to it
3. prints a public `https://...trycloudflare.com` URL

Keep that terminal running while you play.

## In the game

Both players use the same public server URL.

Host:

1. click `Host Online Game`
2. paste the Cloudflare URL
3. click `Create Room Code`
4. share the room code with your friend
5. when the guest connects, click `Start Match`

Guest:

1. click `Join Online Game`
2. paste the same Cloudflare URL
3. enter the host's room code
4. click `Join By Code`

## Notes

- This is a prototype setup meant for testing and friend-play sessions.
- The host remains authoritative over battle state.
- If you stop the terminal running `start_online_tunnel.sh`, the online session ends.
- Cloudflare Quick Tunnel URLs change when restarted, so share the fresh URL each session.
