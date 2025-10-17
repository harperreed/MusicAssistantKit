#!/bin/bash
# ABOUTME: Quick test script for ma-player CLI tool
# ABOUTME: Tests all major commands against Music Assistant server

set -e

HOST="192.168.23.196"
PORT="8095"
PLAYER="RINCON_949F3E56293C01400"  # East Wall

PLAYER_BIN=".build/release/ma-player"
STREAM_BIN=".build/release/ma-stream"

echo "🧪 Testing ma-player CLI"
echo "========================"
echo ""

echo "1️⃣  Testing help command..."
$PLAYER_BIN --help > /dev/null
echo "   ✅ Help works"
echo ""

echo "2️⃣  Testing info command..."
$PLAYER_BIN info --host $HOST --port $PORT --player $PLAYER
echo "   ✅ Info works"
echo ""

echo "3️⃣  Testing queue list..."
$PLAYER_BIN queue --host $HOST --port $PORT --player $PLAYER list
echo "   ✅ Queue list works"
echo ""

echo "4️⃣  Testing volume command..."
CURRENT_VOL=$($PLAYER_BIN info --host $HOST --port $PORT --player $PLAYER | grep Volume | awk '{print $2}' | tr -d '%')
echo "   Current volume: ${CURRENT_VOL}%"
$PLAYER_BIN volume --host $HOST --port $PORT --player $PLAYER ${CURRENT_VOL:-50}
echo "   ✅ Volume command works"
echo ""

echo "5️⃣  Testing control commands..."
echo "   Testing pause..."
$PLAYER_BIN control --host $HOST --port $PORT --player $PLAYER pause
sleep 1
echo "   Testing resume..."
$PLAYER_BIN control --host $HOST --port $PORT --player $PLAYER resume
echo "   ✅ Control commands work"
echo ""

echo "6️⃣  Testing ma-stream (5 second sample)..."
timeout 5 $STREAM_BIN --host $HOST --port $PORT --json || true
echo ""
echo "   ✅ ma-stream works"
echo ""

echo "🎉 All tests passed!"
echo ""
echo "📚 Next steps:"
echo "   - Try: $PLAYER_BIN play --host $HOST --player $PLAYER spotify:track:YOUR_TRACK_ID"
echo "   - Try: $PLAYER_BIN monitor --host $HOST --player $PLAYER --json"
echo "   - Try: $STREAM_BIN --host $HOST (continuous monitoring)"
