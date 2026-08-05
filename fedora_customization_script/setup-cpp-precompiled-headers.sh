#!/usr/bin/env bash
# Setup Script for C++20 Precompiled Headers (PCH) & Mold Linker on Fedora Linux
# Target: Codeforces / Competitive Programming Directory

set -e

TARGET_DIR="${1:-$HOME/Documents/Codeforces}"

echo "=========================================="
echo "Setting up C++20 Precompiled Headers & Mold"
echo "Target Directory: $TARGET_DIR"
echo "=========================================="

mkdir -p "$TARGET_DIR/bits"
mkdir -p "$TARGET_DIR/ext/pb_ds"

# 1. Write Header Files with #include_next to avoid 200-depth include recursion
cat << 'EOF' > "$TARGET_DIR/bits/stdc++.h"
#ifndef BITS_STDCPP_H
#define BITS_STDCPP_H
#include <iostream>
#include <vector>
#include <string>
#include <string_view>
#include <algorithm>
#include <map>
#include <unordered_map>
#include <set>
#include <unordered_set>
#include <queue>
#include <deque>
#include <stack>
#include <cmath>
#include <numeric>
#include <utility>
#include <functional>
#include <bitset>
#include <tuple>
#include <chrono>
#include <random>
#include <complex>
#include <iomanip>
#include <climits>
#include <cstring>
#include <cassert>
#include <concepts>
#include <ranges>
#endif
EOF

cat << 'EOF' > "$TARGET_DIR/ext/pb_ds/assoc_container.hpp"
#ifndef EXT_PBDS_ASSOC_CONTAINER_HPP
#define EXT_PBDS_ASSOC_CONTAINER_HPP
#include_next <ext/pb_ds/assoc_container.hpp>
#endif
EOF

cat << 'EOF' > "$TARGET_DIR/ext/pb_ds/tree_policy.hpp"
#ifndef EXT_PBDS_TREE_POLICY_HPP
#define EXT_PBDS_TREE_POLICY_HPP
#include_next <ext/pb_ds/tree_policy.hpp>
#endif
EOF

# 2. Write build_pch.sh in Target Directory
cat << 'EOF' > "$TARGET_DIR/build_pch.sh"
#!/usr/bin/env bash
# Script to build precompiled headers (PCH) for Codeforces (C++20)

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Building C++20 precompiled headers in $DIR..."

precompile_header() {
    local header_path="$1"       # e.g. bits/stdc++.h
    local gch_path="${header_path}.gch" # e.g. bits/stdc++.h.gch

    echo "Precompiling $header_path -> $gch_path"
    rm -rf "$gch_path"
    g++ -std=c++20 -O0 -pipe -I. -x c++-header -o "$gch_path" "$header_path"
}

precompile_header "bits/stdc++.h"
precompile_header "ext/pb_ds/assoc_container.hpp"
precompile_header "ext/pb_ds/tree_policy.hpp"

echo "Precompiled headers built successfully!"
ls -lh bits/stdc++.h.gch ext/pb_ds/*.gch
EOF
chmod +x "$TARGET_DIR/build_pch.sh"

# 3. Install mold fast linker if missing
if [ ! -f "$HOME/.local/bin/mold" ]; then
    echo "Installing mold fast linker to $HOME/.local/bin/mold..."
    mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
    curl -sL https://github.com/rui314/mold/releases/download/v2.36.0/mold-2.36.0-x86_64-linux.tar.gz | tar -xz -C "$HOME/.local/" --strip-components=1
fi

# 4. Write compile_flags.txt for Neovim / clangd LSP
cat << EOF > "$TARGET_DIR/compile_flags.txt"
-std=c++20
-I.
-I$TARGET_DIR
EOF

# 5. Compile Precompiled Headers
echo "Compiling headers..."
"$TARGET_DIR/build_pch.sh"

# 6. Add CPLUS_INCLUDE_PATH to Shell Configs (~/.zshrc and ~/.bashrc)
for RC_FILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$RC_FILE" ]; then
        if ! grep -q "CPLUS_INCLUDE_PATH.*$TARGET_DIR" "$RC_FILE"; then
            echo "Adding CPLUS_INCLUDE_PATH export to $RC_FILE..."
            echo "export CPLUS_INCLUDE_PATH=\"$TARGET_DIR:\$CPLUS_INCLUDE_PATH\"" >> "$RC_FILE"
        fi
    fi
done

echo "=========================================="
echo "Setup Complete!"
echo "Precompiled headers & mold linker active in $TARGET_DIR"
echo "=========================================="
