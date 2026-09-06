#!/bin/bash
# Update munin-compatible RRD files from throttle's munin-plugin.
#
# Throttle's stats pages (src/Throttle/Stats.php) read per-field RRDs with
# rrdtool, expecting munin's on-disk layout:
#   $MUNIN_RRDDIR/$MUNIN_HOST-throttle_<graph>-<field>-d.rrd  (DS name "42")
# Historically these were written by a munin master polling ./munin-plugin
# every 5 minutes. This script does the same job on a schedule (see
# throttle-graphs.sh and the `graphs` compose service) without requiring a
# full munin master, and stores the RRDs on the `munin_data` volume.
set -euo pipefail

RRDDIR="${MUNIN_RRDDIR:-/var/lib/munin}"
MUNIN_HOST="${MUNIN_HOST:-throttle}"
PLUGIN="${MUNIN_PLUGIN:-/var/www/throttle/munin-plugin}"
STEP=300

mkdir -p "$RRDDIR"

# graph -> "DSTYPE field field ..."
graph_spec() {
	case "$1" in
	throttle_submitted) echo "DERIVE presubmitted submitted accepted rejected_no_minidump rejected_no_steam rejected_rate_limit" ;;
	throttle_processed) echo "DERIVE processed failed needs_reprocessing" ;;
	throttle_cleaned) echo "DERIVE limit old orphan" ;;
	throttle_symbols) echo "DERIVE missing_memory missing found cached found_memory" ;;
	throttle_repocache) echo "DERIVE miss hit" ;;
	throttle_userupdate) echo "DERIVE updated failed" ;;
	throttle_processingtime) echo "GAUGE min avg max" ;;
	*) echo "" ;;
	esac
}

rrd_file() { echo "$RRDDIR/$MUNIN_HOST-$1-$2-d.rrd"; }

create_rrd() {
	local graph="$1" type="$2" field="$3" file
	file="$(rrd_file "$graph" "$field")"
	[ -e "$file" ] && return 0
	local ds="DS:42:$type:600"
	if [ "$type" = "DERIVE" ]; then ds="$ds:0:U"; else ds="$ds:U:U"; fi
	rrdtool create "$file" --step "$STEP" --start "$(($(date +%s) - 7200))" \
		"$ds" \
		RRA:AVERAGE:0.5:1:8640 RRA:MIN:0.5:1:8640 RRA:MAX:0.5:1:8640 \
		RRA:AVERAGE:0.5:12:8760 RRA:MIN:0.5:12:8760 RRA:MAX:0.5:12:8760 \
		RRA:AVERAGE:0.5:288:730 RRA:MIN:0.5:288:730 RRA:MAX:0.5:288:730
	echo "created $file"
}

# Pre-create everything so a fresh volume is complete after one run.
for graph in throttle_submitted throttle_processed throttle_cleaned throttle_symbols throttle_repocache throttle_userupdate throttle_processingtime; do
	spec="$(graph_spec "$graph")"
	type="${spec%% *}"
	fields="${spec#* }"
	for field in $fields; do create_rrd "$graph" "$type" "$field"; done
done

# Feed one plugin pass into the RRDs (unknown/empty values become "U").
graph=""
php "$PLUGIN" 2>/dev/null | while IFS= read -r line; do
	if [[ "$line" =~ ^multigraph\ ([A-Za-z0-9_]+) ]]; then
		graph="${BASH_REMATCH[1]}"
		continue
	fi
	if [[ "$line" =~ ^([A-Za-z0-9_]+)\.value\ (.+)$ ]]; then
		field="${BASH_REMATCH[1]}"
		val="$(echo "${BASH_REMATCH[2]}" | tr -d '[:space:]')"
		[[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] || val="U"
		file="$(rrd_file "$graph" "$field")"
		if [ -e "$file" ]; then
			rrdtool update "$file" "N:$val" || echo "update failed for $file" >&2
		else
			echo "no RRD for $graph/$field, skipping" >&2
		fi
	fi
done

echo "rrd update pass done ($(date -u +%FT%TZ))"
