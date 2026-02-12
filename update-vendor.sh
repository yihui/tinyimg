#!/bin/bash
# Script to update vendored Rust dependencies
# This should be run whenever you need to update the Rust crates

set -e

echo "Updating Rust dependencies for optimg..."
cd "$(dirname "$0")/src/rust"

echo "Step 1: Removing old vendor directory..."
rm -rf vendor

echo "Step 2: Updating Cargo.lock..."
cargo update

echo "Step 3: Vendoring dependencies with versioned directories..."
cargo vendor --versioned-dirs

echo ""
echo "✓ Dependencies updated successfully!"
echo ""
echo "The vendored crates are now in src/rust/vendor/"
echo "Make sure to commit the changes to the repository."
