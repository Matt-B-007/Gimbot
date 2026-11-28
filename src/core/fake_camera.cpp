// SPDX-License-Identifier: MIT
// An in-memory Tiny 2 for tests and for working on the UI without hardware.
// It remembers everything it is told and reports it back like the real
// camera does, including a gimbal that moves at the requested speed.
#include "camera.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <map>
#include <mutex>

namespace t2 {

namespace {

using Clock = std::chrono::steady_clock;

class FakeCamera final : public Camera
{
public:
    FakeCamera()
    {
        s_.valid = true;
        s_.ledLevel = 2; // like a Tiny 2 out of the box
        s_.hasSleepPicture = true;
        s_.mode = Mode::Person;
        s_.framing = 1;
        s_.autoFocus = true;
        s_.faceFocus = true;
        s_.mirrored = true;
        s_.antiFlicker = 3;
        image_ = {{ImageParam::Brightness, 50},
                  {ImageParam::Contrast, 50},
                  {ImageParam::Saturation, 50},
                  {ImageParam::Sharpness, 50},
                  {ImageParam::Hue, 50}};
        presets_ = {{0, "Desk", 12, 0, 1.2f}, {1, "Whiteboard", 0, 35, 1.0f}};
        // Set GIMBOT_FAKE_FAIL=1 to make every command fail, to test errors.
        fail_ = std::getenv("GIMBOT_FAKE_FAIL") != nullptr;
    }

    std::string model() const override { return "OBSBOT Tiny 2 (simulated)"; }
    std::string serial() const override { return "FAKE00000001"; }
    std::string firmware() const override { return "0.0.0-sim"; }

    void onStatus(std::function<void(const Status &)> fn) override
    {
        std::lock_guard<std::mutex> l(m_);
        fn_ = std::move(fn);
    }
    Status status() const override
    {
        std::lock_guard<std::mutex> l(m_);
        return s_;
    }

    bool setAsleep(bool v) override
    {
        return change([&] { s_.asleep = v; });
    }
    bool setSleepTimer(int) override { return !fail_; }
    bool setMicDuringSleep(bool v) override
    {
        return change([&] { s_.micDuringSleep = v; });
    }

    bool setMode(Mode m, Framing f) override
    {
        return change([&] {
            s_.mode = m;
            s_.framing = static_cast<int>(f);
        });
    }
    bool setTrackStyle(TrackStyle) override { return !fail_; }
    bool setAutoZoom(bool) override { return !fail_; }
    bool setGesture(int, bool) override { return !fail_; }

    bool setZoneEnabled(bool v) override { return set(zoneOn_, v); }
    bool zoneEnabled(bool &v) const override { return get(zoneOn_, v); }
    bool setZone(const Zone &z) override { return set(zone_, z); }
    bool zone(Zone &z) const override { return get(zone_, z); }
    bool resetZone() override { return set(zone_, Zone{}); }
    bool setZoneAutoSelect(bool v) override { return set(autoSelect_, v); }
    bool zoneAutoSelect(bool &v) const override { return get(autoSelect_, v); }
    bool zoneStartUseCurrent() override { return !fail_; }
    bool zoneStartGo() override { return !fail_; }
    bool zoneStartReset() override { return !fail_; }

    bool bootUseCurrent() override { return !fail_; }
    bool bootGo() override { return moveTo(0, 0); }
    bool bootReset() override { return !fail_; }
    bool setBootMode(Mode m, Framing) override
    {
        return change([&] { s_.bootMode = static_cast<int>(m); });
    }

    bool move(double pitchSpeed, double yawSpeed) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        integrate();
        pitchSpeed_ = pitchSpeed;
        yawSpeed_ = yawSpeed;
        return true;
    }
    bool moveTo(float pitch, float yaw, float speed = 0) override
    {
        (void)speed; // the simulation arrives instantly
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        pitchSpeed_ = yawSpeed_ = 0;
        pos_.pitch = std::clamp(pitch, -90.f, 90.f);
        pos_.yaw = std::clamp(yaw, -120.f, 120.f);
        return true;
    }
    bool recenter() override { return moveTo(0, 0); }
    bool position(GimbalPos &out) const override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        const_cast<FakeCamera *>(this)->integrate();
        out = pos_;
        return true;
    }
    bool setYawReverse(bool) override { return !fail_; }

    bool setZoom(int p) override
    {
        return change([&] { s_.zoomPercent = std::clamp(p, 0, 100); });
    }
    bool setZoomSpeed(int) override { return !fail_; }
    bool setZoomAtSpeed(int p, int) override { return setZoom(p); }

    bool setFov(Fov f) override
    {
        return change([&] { s_.fov = static_cast<int>(f); });
    }
    bool setHdr(bool v) override
    {
        return change([&] { s_.hdr = v; });
    }
    bool setMirror(bool v) override
    {
        return change([&] { s_.mirrored = v; });
    }
    bool setAutoFocus(bool v) override
    {
        return change([&] { s_.autoFocus = v; });
    }
    bool setManualFocus(int v) override
    {
        return change([&] {
            s_.manualFocus = v;
            s_.autoFocus = false;
        });
    }
    bool setFaceFocus(bool v) override
    {
        return change([&] { s_.faceFocus = v; });
    }
    bool setFaceExposure(bool v) override
    {
        return change([&] { s_.faceExposure = v; });
    }
    bool setAntiFlicker(int v) override
    {
        return change([&] { s_.antiFlicker = v; });
    }
    bool setExposure(bool a, int v) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        autoExposure_ = a;
        shutter_ = v;
        return true;
    }
    bool exposure(bool &a, int &v) const override
    {
        std::lock_guard<std::mutex> l(m_);
        a = autoExposure_;
        v = shutter_;
        return !fail_;
    }
    bool setWhiteBalance(int mode, int kelvin) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        wbMode_ = mode;
        wbKelvin_ = kelvin;
        return true;
    }
    bool whiteBalance(int &mode, int &kelvin) const override
    {
        std::lock_guard<std::mutex> l(m_);
        mode = wbMode_;
        kelvin = wbKelvin_;
        return !fail_;
    }
    Range whiteBalanceRange() const override { return {2000, 10000, 100, 5000, true}; }
    bool setImage(ImageParam p, int v) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        image_[p] = v;
        return true;
    }
    bool image(ImageParam p, int &v) const override
    {
        std::lock_guard<std::mutex> l(m_);
        v = image_.at(p);
        return !fail_;
    }
    Range imageRange(ImageParam) const override { return {0, 100, 1, 50, true}; }

    bool setAudioAutoGain(bool v) override
    {
        return change([&] { s_.audioAutoGain = v; });
    }
    bool setVoiceCommand(Voice v, bool on) override
    {
        return change([&] {
            const int bit = 1 << static_cast<int>(v);
            s_.voiceMask = on ? (s_.voiceMask | bit) : (s_.voiceMask & ~bit);
        });
    }
    bool setVoiceLanguage(VoiceLanguage lang) override
    {
        return change([&] { s_.voiceLanguage = static_cast<int>(lang); });
    }

    std::vector<Preset> presets() const override
    {
        std::lock_guard<std::mutex> l(m_);
        return presets_;
    }
    bool savePreset(int id, const std::string &name) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        integrate();
        presets_.erase(std::remove_if(presets_.begin(), presets_.end(), [id](const Preset &p) { return p.id == id; }),
                       presets_.end());
        presets_.push_back({id, name, pos_.pitch, pos_.yaw, 1.0f + s_.zoomPercent / 100.0f});
        std::sort(presets_.begin(), presets_.end(), [](const Preset &a, const Preset &b) { return a.id < b.id; });
        return true;
    }
    bool goToPreset(int id) override
    {
        Preset target;
        {
            std::lock_guard<std::mutex> l(m_);
            auto it = std::find_if(presets_.begin(), presets_.end(), [id](const Preset &p) { return p.id == id; });
            if (fail_ || it == presets_.end()) return false;
            target = *it;
        }
        return moveTo(target.pitch, target.yaw);
    }
    bool deletePreset(int id) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        presets_.erase(std::remove_if(presets_.begin(), presets_.end(), [id](const Preset &p) { return p.id == id; }),
                       presets_.end());
        return true;
    }
    bool renamePreset(int id, const std::string &name) override
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        for (auto &p : presets_)
            if (p.id == id) p.name = name;
        return true;
    }

    bool setGuideLight(bool) override { return !fail_; }
    bool setSleepPicture(int index) override
    {
        return change([&] { s_.sleepPicture = std::clamp(index, 0, 2); });
    }
    bool setSleepPictureMirrored(bool on) override
    {
        return change([&] { s_.sleepPictureMirrored = on; });
    }
    bool factoryReset() override
    {
        {
            std::lock_guard<std::mutex> l(m_);
            if (fail_) return false;
            presets_.clear();
            zone_ = Zone{};
            zoneOn_ = false;
        }
        return change([&] {
            Status fresh;
            fresh.valid = true;
            s_ = fresh;
        });
    }

private:
    template <typename F>
    bool change(F &&f)
    {
        std::function<void(const Status &)> fn;
        Status copy;
        {
            std::lock_guard<std::mutex> l(m_);
            if (fail_) return false;
            f();
            fn = fn_;
            copy = s_;
        }
        if (fn) fn(copy);
        return true;
    }
    template <typename T>
    bool set(T &field, const T &v)
    {
        std::lock_guard<std::mutex> l(m_);
        if (fail_) return false;
        field = v;
        return true;
    }
    template <typename T>
    bool get(const T &field, T &out) const
    {
        std::lock_guard<std::mutex> l(m_);
        out = field;
        return !fail_;
    }
    void integrate() // caller holds m_
    {
        const auto now = Clock::now();
        const double dt = std::chrono::duration<double>(now - last_).count();
        last_ = now;
        pos_.pitch = std::clamp(static_cast<float>(pos_.pitch + pitchSpeed_ * dt), -90.f, 90.f);
        pos_.yaw = std::clamp(static_cast<float>(pos_.yaw + yawSpeed_ * dt), -120.f, 120.f);
    }

    mutable std::mutex m_;
    std::function<void(const Status &)> fn_;
    Status s_;
    GimbalPos pos_;
    double pitchSpeed_ = 0, yawSpeed_ = 0;
    Clock::time_point last_ = Clock::now();
    std::map<ImageParam, int> image_;
    std::vector<Preset> presets_;
    Zone zone_;
    bool zoneOn_ = false, autoSelect_ = true, autoExposure_ = true, fail_ = false;
    int shutter_ = 30, wbMode_ = wb::Auto, wbKelvin_ = 5000;
};

} // namespace

std::unique_ptr<Camera> openFakeCamera()
{
    return std::make_unique<FakeCamera>();
}

} // namespace t2
