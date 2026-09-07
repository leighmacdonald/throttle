#!/bin/bash
# Long-running loop for the `graphs` compose service: feed throttle's
# munin-plugin counters into RRD files every $GRAPH_INTERVAL seconds
# (munin default: 300). RRDs live on the `munin_data` volume.
set -euo pipefail
INTERVAL="${GRAPH_INTERVAL:-300}"
echo "throttle graphs: updating ${MUNIN_RRDDIR:-/var/lib/munin} every ${INTERVAL}s"
while true; do
	/usr/local/bin/munin-update.sh || echo "munin-update failed, retrying in ${INTERVAL}s" >&2
	/usr/local/bin/munin-graph.sh || echo "munin-graph failed, retrying in ${INTERVAL}s" >&2
	sleep "$INTERVAL"
done
