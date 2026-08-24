#!/usr/bin/env bash
set -e

echo "=================================================="
echo "   Installing Full-GPL FFmpeg with all codecs     "
echo "=================================================="

# 1. Tap the homebrew-ffmpeg repository
echo "==> Tapping homebrew-ffmpeg..."
brew tap homebrew-ffmpeg/ffmpeg

# 2. Unlink standard ffmpeg if already linked
if brew list ffmpeg &>/dev/null; then
    echo "==> Unlinking standard ffmpeg..."
    brew unlink ffmpeg || true
fi

# 3. Install full FFmpeg with AMR speech codec support
echo "==> Installing homebrew-ffmpeg/ffmpeg/ffmpeg --with-opencore-amr..."
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-opencore-amr

# 4. Link the full ffmpeg binary
echo "==> Linking full ffmpeg binary..."
brew link --overwrite homebrew-ffmpeg/ffmpeg/ffmpeg

# 5. Verify installed version & codecs
echo "==> Verifying FFmpeg installation..."
which ffmpeg
ffmpeg -version | head -n 2

echo ""
echo "Full FFmpeg installed successfully!"
echo "You can now run './test_ffmpeg.sh' to test all format configurations."
