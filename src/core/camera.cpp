// SPDX-License-Identifier: MIT
#include "camera.hpp"

#include <algorithm>
#include <cmath>

namespace t2 {

const char *modeName(Mode m)
{
    switch (m) {
    case Mode::Off: return "off";
    case Mode::Group: return "group";
    case Mode::Person: return "person";
    case Mode::Hand: return "hand";
    case Mode::Whiteboard: return "whiteboard";
    case Mode::Desk: return "desk";
    }
    return "unknown";
}

const char *shutter::label(int value)
{
    static const char *labels[] = {"1/8000", "1/6400", "1/5000", "1/4000", "1/3200", "1/2500", "1/2000", "1/1600",
                                   "1/1250", "1/1000", "1/800",  "1/640",  "1/500",  "1/400",  "1/320",  "1/240",
                                   "1/200",  "1/160",  "1/120",  "1/100",  "1/80",   "1/60",   "1/50",   "1/40",
                                   "1/30",   "1/25",   "1/20",   "1/15",   "1/12.5", "1/10",   "1/8",    "1/6.25",
                                   "1/5",    "1/4",    "1/3",    "1/2.5",  "1/2"};
    static_assert(sizeof(labels) / sizeof(labels[0]) == Last - First + 1, "one label per shutter speed");
    if (value < First || value > Last) return "auto";
    return labels[value - First];
}

float glideSpeed(Smoothness s)
{
    switch (s) {
    case Smoothness::Fast: return 0;
    case Smoothness::Normal: return 60;
    case Smoothness::Smooth: return 30;
    case Smoothness::Cinematic: return 12;
    }
    return 0;
}

int glideZoomSpeed(Smoothness s)
{
    switch (s) {
    case Smoothness::Fast: return 0;
    case Smoothness::Normal: return 6;
    case Smoothness::Smooth: return 3;
    case Smoothness::Cinematic: return 1;
    }
    return 0;
}

bool Camera::aimAt(double x, double y, const axis::Orientation &o, float speed)
{
    // Angles from the picture's centre to the clicked point. The field of
    // view setting is diagonal; for a 16:9 picture each one works out as
    // below. Zoom narrows it (0..100% is 1x..4x on the Tiny 2).
    constexpr double kPi = 3.14159265358979323846;
    constexpr double kDiag[] = {86, 78, 65};
    const Status st = status();
    const double diag = kDiag[std::clamp(st.fov, 0, 2)] * kPi / 180;
    const double d = std::sqrt(16.0 * 16 + 9 * 9);
    const double tanHalfH = std::tan(diag / 2) * 16 / d;
    const double tanHalfV = std::tan(diag / 2) * 9 / d;
    GimbalPos pos;
    if (!position(pos)) return false;
    const double zoom = 1.0 + 3.0 * st.zoomPercent / 100.0;
    const double right = std::clamp(x, 0.0, 1.0) * 2 - 1; // -1 left .. 1 right
    const double up = 1 - std::clamp(y, 0.0, 1.0) * 2;    // -1 bottom .. 1 top
    const double rightDeg = std::atan(tanHalfH * right / zoom) * 180 / kPi;
    const double upDeg = std::atan(tanHalfV * up / zoom) * 180 / kPi;
    return moveTo(static_cast<float>(pos.pitch + axis::pitchFromScreen(upDeg, o)),
                  static_cast<float>(pos.yaw + axis::yawFromScreen(rightDeg, o)), speed);
}

bool Camera::glideToPreset(int id, float speed, int zoomSpeed)
{
    if (speed <= 0) return goToPreset(id);
    for (const auto &p : presets()) {
        if (p.id != id) continue;
        // Preset zoom is the SDK's normalised 1.0..2.0, i.e. 0..100%.
        const int percent = std::clamp(static_cast<int>(std::lround((p.zoom - 1.0f) * 100)), 0, 100);
        const bool moved = moveTo(p.pitch, p.yaw, speed);
        const bool zoomed = setZoomAtSpeed(percent, zoomSpeed);
        return moved && zoomed;
    }
    return false;
}

} // namespace t2
