#include "previewformat.hpp"

#include <algorithm>
#include <cstdlib>

namespace preview {

int choose(const std::vector<Format> &formats, int targetHeight, int quality)
{
    if (formats.empty()) return -1;
    // Smooth frame rates first; fall back to whatever there is.
    std::vector<int> pool;
    for (int i = 0; i < int(formats.size()); ++i)
        if (formats[i].maxFps >= 29.5f && formats[i].height > 0) pool.push_back(i);
    if (pool.empty())
        for (int i = 0; i < int(formats.size()); ++i) pool.push_back(i);

    int want = 0;
    switch (quality) {
    case 1: want = 720; break;
    case 2: want = 1080; break;
    case 3: want = 2160; break;
    // Auto: enough for the window, between 720p and 1080p. 4K at 30 fps
    // looks no better in a window than 1080p at 60, and costs a lot more CPU
    // to decode, so it's only used when chosen.
    default: want = std::clamp(targetHeight, 720, 1080); break;
    }

    auto better = [&](int a, int b) { // is format a a better pick than b?
        const Format &fa = formats[a], &fb = formats[b];
        if (quality == 0) {
            // The smallest resolution that still covers the target; if none
            // does, the largest available.
            const bool ca = fa.height >= want, cb = fb.height >= want;
            if (ca != cb) return ca;
            if (fa.height != fb.height) return ca ? fa.height < fb.height : fa.height > fb.height;
        } else {
            const int da = std::abs(fa.height - want), db = std::abs(fb.height - want);
            if (da != db) return da < db;
            if (fa.height != fb.height) return fa.height > fb.height; // equal distance: sharper
        }
        if (fa.width != fb.width) return fa.width > fb.width;
        if (fa.maxFps != fb.maxFps) return fa.maxFps > fb.maxFps;
        return !fa.compressed && fb.compressed;
    };
    int best = pool.front();
    for (int i : pool)
        if (better(i, best)) best = i;
    return best;
}

std::vector<Choice> choices(const std::vector<Format> &formats)
{
    std::vector<Choice> out;
    for (int i = 0; i < int(formats.size()); ++i) {
        const Format &f = formats[size_t(i)];
        const int fps = int(f.maxFps + 0.5f);
        if (f.width <= 0 || f.height <= 0 || fps < 15) continue;
        auto it = std::find_if(out.begin(), out.end(), [&](const Choice &c) {
            return c.width == f.width && c.height == f.height && c.fps == fps;
        });
        if (it == out.end()) {
            out.push_back({f.width, f.height, fps, i});
        } else if (formats[size_t(it->format)].compressed && !f.compressed) {
            it->format = i; // same picture without decoding
        }
    }
    std::sort(out.begin(), out.end(), [](const Choice &a, const Choice &b) {
        if (a.height != b.height) return a.height > b.height;
        if (a.width != b.width) return a.width > b.width;
        return a.fps > b.fps;
    });
    return out;
}

int find(const std::vector<Format> &formats, int width, int height, int fps)
{
    for (const auto &c : choices(formats))
        if (c.width == width && c.height == height && c.fps == fps) return c.format;
    return -1;
}

} // namespace preview
