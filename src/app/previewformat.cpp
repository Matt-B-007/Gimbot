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
    default: want = std::max(720, targetHeight); break; // never below 720p
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

} // namespace preview
