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
    static const char *labels[] = {"1/8000", "1/6400", "1/5000", "1/4000", "1/3200", "1/2500", "1/2000",
                                   "1/1600", "1/1250", "1/1000", "1/800",  "1/640",  "1/500",  "1/400",
                                   "1/320",  "1/240",  "1/200",  "1/160",  "1/120",  "1/100",  "1/80",
                                   "1/60",   "1/50",   "1/40",   "1/30",   "1/25",   "1/20",   "1/15",
                                   "1/12.5", "1/10",   "1/8",    "1/6.25", "1/5",    "1/4",    "1/3",
                                   "1/2.5",  "1/2"};
    if (value < First || value > Last) return "auto";
    return labels[value - First];
}

bool Camera::aimAt(double x, double y)
{
    // Angles from the image centre to the clicked point. The Tiny 2's 86°
    // FOV is diagonal; for a 16:9 frame that is about 78° x 49°. Digital
    // zoom narrows it (assumed 1x..4x across the 0..100% zoom range).
    constexpr double kPi = 3.14159265358979323846;
    constexpr double kHalfH = 78.2 / 2 * kPi / 180;
    constexpr double kHalfV = 49.1 / 2 * kPi / 180;
    GimbalPos pos;
    if (!position(pos)) return false;
    const double zoom = 1.0 + 3.0 * status().zoomPercent / 100.0;
    const double dx = std::clamp(x, 0.0, 1.0) * 2 - 1; // -1 left .. 1 right
    const double dy = std::clamp(y, 0.0, 1.0) * 2 - 1; // -1 top .. 1 bottom
    const double yawDelta = std::atan(std::tan(kHalfH) * dx / zoom) * 180 / kPi;
    const double pitchDelta = std::atan(std::tan(kHalfV) * dy / zoom) * 180 / kPi;
    // Positive yaw turns the camera to its left (the viewer's right in an
    // unmirrored image); positive pitch tilts up. To be confirmed on hardware;
    // the app has "invert" settings in case it is the other way round.
    return moveTo(static_cast<float>(pos.pitch - pitchDelta), static_cast<float>(pos.yaw - yawDelta));
}

} // namespace t2
