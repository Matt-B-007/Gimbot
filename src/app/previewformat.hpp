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

// quality: 0 = auto (enough for targetHeight pixels on screen, 720p..1080p,
// preferring the smoother frame rate), 1 = 720p, 2 = 1080p, 3 = 4K. Returns an index into formats, or -1 if it is empty.
int choose(const std::vector<Format> &formats, int targetHeight, int quality);

// One entry in the preview quality menu: a resolution and frame rate the
// camera really offers. Several formats (raw, MJPEG) can share one entry.
struct Choice {
    int width = 0, height = 0, fps = 0;
    int format = -1; // index of the best format for it (raw wins a tie)
};

// Every distinct resolution + frame rate, sharpest first, then fastest.
// Formats below 15 fps are left out (too choppy to be worth offering).
std::vector<Choice> choices(const std::vector<Format> &formats);

// The format for a menu entry, or -1 if this camera doesn't offer it.
int find(const std::vector<Format> &formats, int width, int height, int fps);

} // namespace preview
