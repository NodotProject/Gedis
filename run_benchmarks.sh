#!/bin/bash
set -e
godot --headless --script res://test/benchmarks/expire.gd
godot --headless --script res://test/benchmarks/performance.gd