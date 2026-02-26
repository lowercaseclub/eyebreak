# mocks.bash — shared helpers for bats tests

setup() {
    MOCK_BIN="$(mktemp -d)"
    MOCK_LOG="$(mktemp)"
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_LOG
    export MOCK_BIN
}

teardown() {
    rm -rf "$MOCK_BIN" "$MOCK_LOG"
}

# create_mock <cmd> [exit_code] [stdout_output]
create_mock() {
    local cmd="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    cat > "$MOCK_BIN/$cmd" <<SCRIPT
#!/bin/bash
echo "$cmd \$*" >> "$MOCK_LOG"
if [ -n "$output" ]; then echo "$output"; fi
exit $exit_code
SCRIPT
    chmod +x "$MOCK_BIN/$cmd"
}

# create_mock_sequence <cmd> <exit_code1> <exit_code2> ...
# Returns exit codes in order, cycling back to last one
create_mock_sequence() {
    local cmd="$1"
    shift
    local codes=("$@")
    local counter_file="$MOCK_BIN/.${cmd}_counter"
    echo "0" > "$counter_file"

    # Write codes array as newline-separated file
    local codes_file="$MOCK_BIN/.${cmd}_codes"
    printf '%s\n' "${codes[@]}" > "$codes_file"

    cat > "$MOCK_BIN/$cmd" <<'SCRIPT'
#!/bin/bash
SCRIPT

    # Append the dynamic part with proper variable expansion
    cat >> "$MOCK_BIN/$cmd" <<SCRIPT
COUNTER_FILE="$counter_file"
CODES_FILE="$codes_file"
LOG_FILE="$MOCK_LOG"
SCRIPT

    cat >> "$MOCK_BIN/$cmd" <<'SCRIPT'
echo "$(basename "$0") $*" >> "$LOG_FILE"
idx=$(cat "$COUNTER_FILE")
total=$(wc -l < "$CODES_FILE" | tr -d ' ')
if [ "$idx" -ge "$total" ]; then
    idx=$((total - 1))
fi
code=$(sed -n "$((idx + 1))p" "$CODES_FILE")
echo $((idx + 1)) > "$COUNTER_FILE"
exit "$code"
SCRIPT
    chmod +x "$MOCK_BIN/$cmd"
}

assert_mock_called() {
    local cmd="$1"
    grep -q "^$cmd " "$MOCK_LOG" 2>/dev/null || grep -q "^$cmd$" "$MOCK_LOG" 2>/dev/null
}

assert_mock_called_with() {
    local cmd="$1"
    shift
    local args="$*"
    grep -q "^$cmd $args" "$MOCK_LOG" 2>/dev/null
}

mock_call_count() {
    local cmd="$1"
    grep -c "^$cmd" "$MOCK_LOG" 2>/dev/null || echo "0"
}
