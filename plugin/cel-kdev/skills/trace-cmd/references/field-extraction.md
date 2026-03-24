# Field extraction recipes

Use awk for extracting `key=value` fields from saved event
files. These patterns are portable, fast on large files, and
immune to the grep -oP pipe hazard.

## Single numeric field

```bash
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt
```

## Count distinct values

Replaces `sort | uniq -c | sort -rn` (which is slow on
400K+ line files):

```bash
awk '{for(i=1;i<=NF;i++) if($i ~ /^proc=/)
  {split($i,a,"="); c[a[2]]++}}
  END{for(v in c) printf "%8d %s\n",c[v],v}' /tmp/latency.txt | sort -rn
```

## Flag extraction

Flags contain `|` characters and need a broader match:

```bash
grep -oE 'flags=[A-Za-z0-9x|_]+' /tmp/enqueue.txt

# Count flag combinations
awk '{match($0,/flags=[A-Za-z0-9x|_]+/);
  if(RSTART) c[substr($0,RSTART,RLENGTH)]++}
  END{for(f in c) printf "%8d %s\n",c[f],f}' /tmp/enqueue.txt | sort -rn
```

## Latency distribution

```bash
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt | \
  sort -n | \
  awk '{a[NR]=$1; s+=$1} END{n=NR;
    printf "n=%d min=%d p50=%d p90=%d p99=%d max=%d mean=%.0f\n",
      n, a[1], a[int(n*0.5)], a[int(n*0.9)], a[int(n*0.99)], a[n], s/n}'
```

## Timestamp extraction

```bash
awk '{match($0, /[0-9]+\.[0-9]+:/); ts=substr($0,RSTART,RLENGTH-1)+0}'
```

## Process name extraction

```bash
awk '{gsub(/^[ \t]+/,""); sub(/-[0-9]+.*$/,""); print}'
```

## Process summary

```bash
trace-cmd report -i <file> 2>&1 | \
  awk '{gsub(/^[ \t]+/,""); sub(/-[0-9]+.*$/,""); c[$0]++}
       END{for(p in c) printf "%8d %s\n",c[p],p}' | \
  sort -rn | head -20
```

## Timestamp windowing

Extract events within a time window from a saved file:

```bash
awk '{match($0, /[0-9]+\.[0-9]+:/);
  ts=substr($0,RSTART,RLENGTH-1)+0;
  if (ts >= 395.9 && ts <= 402.0) print}' /tmp/dequeue.txt | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^wakeup-us=/)
    {split($i,a,"="); print a[2]}}' | sort -n
```

## Phase detection

```bash
# Find WRITE phase boundaries
grep 'proc=WRITE' /tmp/latency.txt | head -1
grep 'proc=WRITE' /tmp/latency.txt | tail -1

# Count events per phase using timestamp windows
awk '{match($0,/[0-9]+\.[0-9]+:/);
  ts=substr($0,RSTART,RLENGTH-1)+0;
  if(ts>=516.5 && ts<=527.0) wr++;
  else if(ts>=528.7 && ts<=545.0) rd++}
  END{print "WRITE:",wr+0; print "READ:",rd+0}' /tmp/enqueue.txt
```

## Working with large traces

For captures with millions of events:

- Save filtered events to temp files early and work from
  the files for all subsequent analysis
- Use field-level `-F` filters to narrow output before
  saving
- Process per-CPU if needed:
  `trace-cmd report -i <file> --cpu <N>`
- For phase-based analysis, use awk timestamp filters on
  saved temp files (see Timestamp windowing above)
