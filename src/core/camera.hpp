// SPDX-License-Identifier: MIT
// Gimbot camera layer.
//
// `Camera` is the interface the app talks to. `openSdkCamera()` returns the
// real implementation on top of OBSBOT's libdev SDK; `openFakeCamera()`
// returns an in-memory stand-in used for tests and for working on the UI
// without hardware (run the app with GIMBOT_FAKE_CAMERA=1).
//
// Every call blocks until the camera answers, so call these from a worker
// thread, never from a GUI thread.
#pragma once

#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace t2 {

// Tracking modes, matching the SDK's AiWorkModeType values.
enum class Mode : int { Off = 0, Group = 1, Person = 2, Hand = 3, Whiteboard = 4, Desk = 5 };

// Person framing, matching AiSubModeType.
enum class Framing : int { FullBody = 0, UpperBody = 1, CloseUp = 2 };

// Tracking style, matching AiVerticalTrackType.
enum class TrackStyle : int { Standard = 0, Headroom = 1, Motion = 2 };

// Field of view, matching FovType.
enum class Fov : int { Wide86 = 0, Medium78 = 1, Narrow65 = 2 };

enum class ImageParam : int { Brightness, Contrast, Saturation, Sharpness, Hue };

// White balance modes, matching DevWhiteBalanceType.
namespace wb {
constexpr int Auto = 0, Daylight = 1, Fluorescent = 2, Tungsten = 3, Cloudy = 10, Manual = 255;
}

// Shutter speeds, matching DevShutterTimeType: 9 = 1/8000 ... 45 = 1/2.
namespace shutter {
constexpr int First = 9, Last = 45;
const char *label(int value); // "1/60" etc.
} // namespace shutter

// Voice commands, matching AudioCtrlCmdType.
enum class Voice : int { HiTiny = 0, SleepTiny, TrackMe, Unlock, ZoomIn, ZoomOut, Presets, Count };
enum class VoiceLanguage : int { Chinese = 0, English = 1 };

struct Status {
    bool valid = false;
    Mode mode = Mode::Off;
    bool modeSwitching = false; // the camera is changing modes; `mode` is not meaningful
    int framing = 0;            // AiSubModeType
    int zoomPercent = 0;        // 0..100
    bool hdr = false;
    bool asleep = false;
    int fov = 0; // FovType
    bool autoFocus = true;
    bool faceFocus = false;
    int manualFocus = 0; // 0..100
    bool mirrored = false;
    bool faceExposure = false;
    int antiFlicker = 0; // 0 off, 1 50 Hz, 2 60 Hz, 3 auto
    int trackSpeed = 0;
    bool micDuringSleep = false;
    int voiceLanguage = 1; // VoiceLanguage
    int voiceMask = 0x7f;  // bit n = Voice n enabled
    bool audioAutoGain = true;
    int bootMode = 0;             // AiWorkModeType the camera starts in
    int ledLevel = -1;            // status light brightness: 0 off, 1..3; -1 = not reported
    bool hasSleepPicture = false; // a picture is set to show while asleep
    int sleepPicture = 0;         // which saved picture (0..2)
    bool sleepPictureMirrored = false;
};

struct Range {
    long min = 0, max = 100, step = 1, def = 50;
    bool valid = false;
};

struct Preset {
    int id = 0;
    std::string name;
    float pitch = 0, yaw = 0, zoom = 1;
};

struct GimbalPos {
    float pitch = 0, yaw = 0;
};

// Region-limited tracking, in the SDK's angle frame (see `axis` below).
struct Zone {
    float yawMin = -120, yawMax = 120, pitchMin = -90, pitchMax = 90;
};

// ---------------------------------------------------------------- directions
//
// The one place that decides which way is up. Every control (arrow keys, the
// aim pad, double-click-to-aim, drag-to-steer, presets, the tracking-area editor)
// converts through these functions, so they can't disagree with each other.
//
// SDK frame, as OBSBOT documents it for the Tiny 2's angle calls:
//   pitch: positive tilts the camera DOWN
//   yaw:   positive turns it to the RIGHT as seen by someone facing the camera
//          (the camera's own left)
// Screen frame, what the user sees in the preview:
//   up:    positive moves the picture's view up
//   right: positive moves the picture's view right
// In an unmirrored picture, turning the camera to its own right shows more
// of what is on the picture's right, so screen-right is negative yaw. A
// mirrored picture flips that. The invert options are a per-user override.
namespace axis {
struct Orientation {
    bool mirrored = false;   // the camera's horizontal flip is on
    bool invertPan = false;  // user override
    bool invertTilt = false; // user override
};
constexpr double kPitchPerUp = -1.0;  // SDK pitch per unit of screen "up"
constexpr double kYawPerRight = -1.0; // SDK yaw per unit of screen "right", unmirrored
inline double yawSign(const Orientation &o)
{
    double s = kYawPerRight;
    if (o.mirrored) s = -s;
    if (o.invertPan) s = -s;
    return s;
}
inline double pitchSign(const Orientation &o)
{
    return o.invertTilt ? -kPitchPerUp : kPitchPerUp;
}
// Both directions use the same sign, so these work for angles and speeds.
inline double yawFromScreen(double right, const Orientation &o)
{
    return yawSign(o) * right;
}
inline double pitchFromScreen(double up, const Orientation &o)
{
    return pitchSign(o) * up;
}
inline double screenFromYaw(double yaw, const Orientation &o)
{
    return yawSign(o) * yaw;
}
inline double screenFromPitch(double pitch, const Orientation &o)
{
    return pitchSign(o) * pitch;
}
} // namespace axis

// ---------------------------------------------------------------- the picture
//
// Where a point in the picture is, as angles from the picture's centre, and
// back. x and y run 0..1 from the left and top; points outside the picture
// are fine (the zone editor needs them). `fov` is the FovType setting
// (diagonal 86, 78 or 65 degrees) and zoom is 0..100% (1x..4x on the Tiny 2).
namespace view {
struct Offset {
    double rightDeg = 0; // + is to the picture's right
    double upDeg = 0;    // + is up
};
// zoomMax is the camera's zoom at 100% (4x on the Tiny 2).
Offset offsetFromPicture(double x, double y, int fov, int zoomPercent, double zoomMax = 4.0);
void pictureFromOffset(const Offset &o, int fov, int zoomPercent, double &x, double &y, double zoomMax = 4.0);

// The circle aim pad: a knob dragged (dx, dy) pixels from the centre of a pad
// with the given radius gives a speed for each direction, -1..1. A little
// dead zone in the middle; it eases in so small drags are gentle; beyond the
// edge it's simply full speed in that direction.
struct PadSpeed {
    double up = 0, right = 0;
};
PadSpeed padSpeed(double dx, double dy, double radius);
} // namespace view

// How fast the gimbal glides to a new position. Fast = the camera's own
// maximum, the others use a reference speed in degrees per second.
enum class Smoothness : int { Fast = 0, Normal = 1, Smooth = 2, Cinematic = 3 };
float glideSpeed(Smoothness s);   // deg/s, 0 = camera maximum
int glideZoomSpeed(Smoothness s); // 1..10, 0 = camera default

class Camera
{
public:
    virtual ~Camera() = default;

    virtual std::string model() const = 0;
    virtual std::string serial() const = 0;
    virtual std::string firmware() const = 0;

    // Live status pushed by the camera. The callback may run on any thread.
    virtual void onStatus(std::function<void(const Status &)> fn) = 0;
    virtual Status status() const = 0;

    // Power
    virtual bool setAsleep(bool asleep) = 0;
    virtual bool setSleepTimer(int seconds) = 0; // 0 = never
    virtual bool setMicDuringSleep(bool on) = 0;

    // Tracking
    virtual bool setMode(Mode mode, Framing framing) = 0;
    virtual bool setTrackStyle(TrackStyle style) = 0;
    virtual bool setAutoZoom(bool on) = 0;
    // 0 select target, 1 zoom, 2 dynamic zoom, 3 reverse dynamic zoom direction
    virtual bool setGesture(int which, bool on) = 0;

    // Region-limited tracking
    virtual bool setZoneEnabled(bool on) = 0;
    virtual bool zoneEnabled(bool &on) const = 0;
    virtual bool setZone(const Zone &z) = 0;
    virtual bool zone(Zone &z) const = 0;
    virtual bool resetZone() = 0;
    virtual bool setZoneAutoSelect(bool on) = 0;
    virtual bool zoneAutoSelect(bool &on) const = 0;
    virtual bool zoneStartUseCurrent() = 0;
    virtual bool zoneStartGo() = 0;
    virtual bool zoneStartReset() = 0;

    // Startup
    virtual bool bootUseCurrent() = 0;
    virtual bool bootGo() = 0;
    virtual bool bootReset() = 0;
    virtual bool setBootMode(Mode mode, Framing framing) = 0;

    // Gimbal
    virtual bool move(double pitchSpeed, double yawSpeed) = 0; // deg/s; 0,0 stops
    // Go to angles in the SDK frame. speed is deg/s, 0 = as fast as possible.
    virtual bool moveTo(float pitch, float yaw, float speed = 0) = 0;
    virtual bool recenter() = 0;
    virtual bool position(GimbalPos &out) const = 0;
    virtual bool setYawReverse(bool on) = 0;
    // Point the camera at a spot in the picture (0..1 from top-left, as seen
    // in the preview).
    bool aimAt(double x, double y, const axis::Orientation &o, float speed = 0);
    // Go to a preset by gliding angle and zoom together, instead of the
    // camera's own jump. speed 0 uses the camera's preset recall.
    bool glideToPreset(int id, float speed, int zoomSpeed);

    // Zoom
    virtual bool setZoom(int percent) = 0;                   // 0..100 of the camera's range
    virtual bool setZoomSpeed(int speed) = 0;                // 0 = camera default, 1..10
    virtual bool setZoomAtSpeed(int percent, int speed) = 0; // one-off speed
    // Magnification at 100% zoom (the Tiny 2 reports its range, usually 4x).
    virtual float maxZoom() const { return 4.0f; }

    // Image
    virtual bool setFov(Fov fov) = 0;
    virtual bool setHdr(bool on) = 0;
    virtual bool setMirror(bool on) = 0;
    virtual bool setAutoFocus(bool on) = 0;
    virtual bool setManualFocus(int value) = 0; // 0..100, turns autofocus off
    virtual bool setFaceFocus(bool on) = 0;
    virtual bool setFaceExposure(bool on) = 0;
    virtual bool setAntiFlicker(int mode) = 0;
    virtual bool setExposure(bool autoExposure, int shutterValue) = 0;
    virtual bool exposure(bool &autoExposure, int &shutterValue) const = 0;
    virtual bool setWhiteBalance(int mode, int kelvin) = 0;
    virtual bool whiteBalance(int &mode, int &kelvin) const = 0;
    virtual Range whiteBalanceRange() const = 0;
    virtual bool setImage(ImageParam p, int value) = 0;
    virtual bool image(ImageParam p, int &value) const = 0;
    virtual Range imageRange(ImageParam p) const = 0;

    // Audio and voice
    virtual bool setAudioAutoGain(bool on) = 0;
    virtual bool setVoiceCommand(Voice v, bool on) = 0;
    virtual bool setVoiceLanguage(VoiceLanguage lang) = 0;

    // Presets (stored on the camera)
    virtual std::vector<Preset> presets() const = 0;
    virtual bool savePreset(int id, const std::string &name) = 0; // current view
    virtual bool goToPreset(int id) = 0;
    virtual bool deletePreset(int id) = 0;
    virtual bool renamePreset(int id, const std::string &name) = 0;

    // The picture the camera shows while asleep (Tiny 2 keeps up to three).
    virtual bool setSleepPicture(int index) = 0; // 0..2
    virtual bool setSleepPictureMirrored(bool on) = 0;

    // Device
    virtual bool setGuideLight(bool on) = 0;
    virtual bool factoryReset() = 0;
};

// ---------------------------------------------------------------- SDK

// Device discovery for real cameras.
class Discovery
{
public:
    using ChangeFn = std::function<void(const std::string &serial, bool connected)>;
    // Returns false if the system has no USB bus to scan (libdev would crash).
    static bool start(ChangeFn fn);
    static void stop();
    static std::vector<std::string> cameras(); // serials of connected Tiny 2s
    static void setVerbose(bool on);           // pass libdev's own log through
};

// The real camera with this serial, or the first Tiny 2 if empty.
std::unique_ptr<Camera> openSdkCamera(const std::string &serial = {});

// In-memory camera for tests and UI work.
std::unique_ptr<Camera> openFakeCamera();

const char *modeName(Mode m);

} // namespace t2
