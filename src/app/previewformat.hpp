// Picks the video format for Gimbot's own preview.
//
// The camera offers many resolution and frame-rate combinations. Without a
// choice Qt takes its default, which is often small or slow, so the preview
// looks soft. This picks the sharpest one worth showing at the preview's
// size on screen, at a smooth frame rate. It only affects Gimbot's preview;
// other apps choose their own.
#pragma once

#include <vector>

namespace preview {

struct Format {
    int width = 0, height = 0;
    float maxFps = 0;
    bool compressed = false; // MJPEG: must be decoded, so raw wins a tie
};

// quality: 0 = auto (sharpest for targetHeight pixels on screen), 1 = 720p,
// 2 = 1080p, 3 = 4K. Returns an index into formats, or -1 if it is empty.
int choose(const std::vector<Format> &formats, int targetHeight, int quality);

} // namespace preview
