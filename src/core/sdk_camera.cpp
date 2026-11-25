// Real camera implementation on top of OBSBOT's libdev SDK.
#include "camera.hpp"

#include <dev/devs.hpp>

#include <algorithm>
#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <sys/stat.h>

namespace t2 {

namespace {

bool ok(int32_t r) { return r == RM_RET_OK; }

bool isTiny2Family(const std::shared_ptr<Device> &d)
{
    if (!d) return false;
    auto t = d->productType();
    return t == ObsbotProdTiny2 || t == ObsbotProdTiny2Lite;
}

Status convert(const Device::CameraStatus &cs)
{
    const auto &t = cs.tiny;
    Status s;
    s.valid = true;
    s.modeSwitching = t.ai_mode == Device::AiWorkModeSwitching;
    s.mode = static_cast<Mode>(t.ai_mode <= 5 ? t.ai_mode : 0);
    s.framing = std::clamp<int>(t.ai_sub_mode, 0, 2);
    s.zoomPercent = std::clamp<int>(t.zoom_ratio, 0, 100);
    s.hdr = t.hdr != 0;
    s.asleep = t.dev_status == Device::DevStatusSleep || t.dev_status == Device::DevStatusPrivacy;
    s.fov = t.fov;
    s.autoFocus = t.auto_focus != 0;
    s.faceFocus = t.face_auto_focus != 0;
    s.manualFocus = t.manual_focus_value;
    s.mirrored = t.image_flip_hor != 0;
    s.faceExposure = t.face_ae != 0;
    s.antiFlicker = t.anti_flicker;
    s.trackSpeed = t.ai_tracker_speed;
    s.micDuringSleep = t.sleep_micro != 0;
    s.voiceLanguage = t.voice_ctrl_language;
    s.voiceMask = t.voice_ctrl;
    s.audioAutoGain = t.audio_auto_gain != 0;
    s.bootMode = t.boot_mode <= 5 ? t.boot_mode : 0;
    return s;
}

Range toRange(const Device::UvcParamRange &r, bool got)
{
    Range out;
    if (!got || r.max_ <= r.min_) return out;
    out.min = r.min_;
    out.max = r.max_;
    out.step = r.step_ > 0 ? r.step_ : 1;
    out.def = r.default_;
    out.valid = true;
    return out;
}

std::mutex g_discoveryMutex;
Discovery::ChangeFn g_onChange;
std::atomic<bool> g_verbose{false};

void sdkLog(int32_t lvl, const char *msg, va_list args, void *)
{
    static const bool envVerbose = std::getenv("GIMBOT_DEBUG") != nullptr;
    if (!envVerbose && !g_verbose && lvl > DEV_ERROR) return;
    std::fputs("libdev: ", stderr);
    std::vfprintf(stderr, msg, args);
}

class SdkCamera final : public Camera {
public:
    explicit SdkCamera(std::shared_ptr<Device> d) : dev_(std::move(d))
    {
        Device::UvcParamRange r{};
        if (ok(dev_->cameraGetRangeZoomAbsoluteR(r)) && r.max_ > r.min_) {
            zoomMin_ = r.min_;
            zoomMax_ = r.max_;
        }
    }

    ~SdkCamera() override
    {
        dev_->enableDevStatusCallback(false);
        dev_->setDevStatusCallbackFunc(nullptr, nullptr);
    }

    std::string model() const override
    {
        return dev_->productType() == ObsbotProdTiny2Lite ? "OBSBOT Tiny 2 Lite" : "OBSBOT Tiny 2";
    }
    std::string serial() const override { return dev_->devSn(); }
    std::string firmware() const override { return dev_->devVersion(); }

    void onStatus(std::function<void(const Status &)> fn) override
    {
        if (!fn) {
            dev_->enableDevStatusCallback(false);
            dev_->setDevStatusCallbackFunc(nullptr, nullptr);
            statusFn_ = nullptr;
            return;
        }
        statusFn_ = std::move(fn);
        dev_->setDevStatusCallbackFunc(
            [](void *self, const void *data) {
                auto *cam = static_cast<SdkCamera *>(self);
                if (data && cam->statusFn_) cam->statusFn_(convert(*static_cast<const Device::CameraStatus *>(data)));
            },
            this);
        dev_->enableDevStatusCallback(true);
    }

    Status status() const override
    {
        Device::CameraStatus cs{};
        if (ok(dev_->cameraGetCameraStatusU(cs))) return convert(cs);
        return convert(dev_->cameraStatus());
    }

    // ---- power
    bool setAsleep(bool asleep) override
    {
        return ok(dev_->cameraSetDevRunStatusR(asleep ? Device::DevStatusSleep : Device::DevStatusRun));
    }
    bool setSleepTimer(int seconds) override { return ok(dev_->cameraSetSuspendTimeU(seconds > 0 ? seconds : -1)); }
    bool setMicDuringSleep(bool on) override { return ok(dev_->cameraSetMicrophoneDuringSleepU(on ? 1 : 0)); }

    // ---- tracking
    bool setMode(Mode mode, Framing framing) override
    {
        int sub = mode == Mode::Person ? static_cast<int>(framing) : 0;
        return ok(dev_->cameraSetAiModeU(static_cast<Device::AiWorkModeType>(mode), sub));
    }
    bool setTrackStyle(TrackStyle style) override
    {
        return ok(dev_->aiSetTrackingModeR(static_cast<Device::AiVerticalTrackType>(style)));
    }
    bool setAutoZoom(bool on) override { return ok(dev_->aiSetAiAutoZoomR(on)); }
    bool setGesture(int which, bool on) override { return ok(dev_->aiSetGestureCtrlIndividualR(which, on)); }

    // ---- zone
    bool setZoneEnabled(bool on) override { return ok(dev_->aiSetLimitedZoneTrackEnabledR(on)); }
    bool zoneEnabled(bool &on) const override { return ok(dev_->aiGetLimitedZoneTrackEnabledR(on)); }
    bool setZone(const Zone &z) override
    {
        bool r = ok(dev_->aiSetLimitedZoneTrackYawMinR(std::clamp(z.yawMin, -120.f, 120.f)));
        r = ok(dev_->aiSetLimitedZoneTrackYawMaxR(std::clamp(z.yawMax, -120.f, 120.f))) && r;
        r = ok(dev_->aiSetLimitedZoneTrackPitchMinR(std::clamp(z.pitchMin, -90.f, 90.f))) && r;
        r = ok(dev_->aiSetLimitedZoneTrackPitchMaxR(std::clamp(z.pitchMax, -90.f, 90.f))) && r;
        return r;
    }
    bool zone(Zone &z) const override
    {
        bool r = ok(dev_->aiGetLimitedZoneTrackYawMinR(z.yawMin, 0));
        r = ok(dev_->aiGetLimitedZoneTrackYawMaxR(z.yawMax, 0)) && r;
        r = ok(dev_->aiGetLimitedZoneTrackPitchMinR(z.pitchMin, 0)) && r;
        r = ok(dev_->aiGetLimitedZoneTrackPitchMaxR(z.pitchMax, 0)) && r;
        return r;
    }
    bool resetZone() override
    {
        bool r = ok(dev_->aiRstLimitedZoneTrackYawMinR());
        r = ok(dev_->aiRstLimitedZoneTrackYawMaxR()) && r;
        r = ok(dev_->aiRstLimitedZoneTrackPitchMinR()) && r;
        r = ok(dev_->aiRstLimitedZoneTrackPitchMaxR()) && r;
        return r;
    }
    bool setZoneAutoSelect(bool on) override { return ok(dev_->aiSetLimitedZoneTrackAutoSelectR(on)); }
    bool zoneAutoSelect(bool &on) const override { return ok(dev_->aiGetLimitedZoneTrackAutoSelectR(on)); }
    bool zoneStartUseCurrent() override
    {
        Device::PresetPosInfo info{};
        if (!currentView(info)) return false;
        return ok(dev_->aiSetLimitedZoneTrackInitPosR(&info));
    }
    bool zoneStartGo() override { return ok(dev_->aiTrgLimitedZoneTrackInitPosR()); }
    bool zoneStartReset() override { return ok(dev_->aiRstLimitedZoneTrackInitPosR()); }

    // ---- startup
    bool bootUseCurrent() override
    {
        Device::PresetPosInfo info{};
        if (!currentView(info)) return false;
        return ok(dev_->aiSetGimbalBootPosR(info));
    }
    bool bootGo() override { return ok(dev_->aiTrgGimbalBootPosR(false)); }
    bool bootReset() override { return ok(dev_->aiRstGimbalBootPosR()); }
    bool setBootMode(Mode mode, Framing framing) override
    {
        auto sub = mode == Mode::Person ? static_cast<Device::AiSubModeType>(framing) : Device::AiSubModeNormal;
        return ok(dev_->cameraSetBootModeU(static_cast<Device::AiWorkModeType>(mode), sub));
    }

    // ---- gimbal
    bool move(double pitchSpeed, double yawSpeed) override
    {
        if (pitchSpeed == 0 && yawSpeed == 0) return ok(dev_->aiSetGimbalStop());
        return ok(dev_->aiSetGimbalSpeedCtrlR(std::clamp(pitchSpeed, -90.0, 90.0), std::clamp(yawSpeed, -180.0, 180.0),
                                              0.0));
    }
    bool moveTo(float pitch, float yaw, float speed = 0) override
    {
        pitch = std::clamp(pitch, -90.f, 90.f);
        if (speed > 0) {
            // Glide at a reference speed (Tiny 2: yaw -120..120, speed up to 90).
            const float s = std::clamp(speed, 1.f, 90.f);
            return ok(dev_->gimbalSetSpeedPositionR(0, pitch, std::clamp(yaw, -120.f, 120.f), 0, s, s));
        }
        return ok(dev_->aiSetGimbalMotorAngleR(pitch, std::clamp(yaw, -180.f, 180.f)));
    }
    bool recenter() override { return ok(dev_->gimbalRstPosR()); }
    bool position(GimbalPos &out) const override
    {
        Device::AiGimbalStateInfo st{};
        if (!ok(dev_->aiGetGimbalStateR(&st))) return false;
        out.pitch = st.pitch_motor;
        out.yaw = st.yaw_motor;
        return true;
    }
    bool setYawReverse(bool on) override { return ok(dev_->aiSetGimbalYawDirReverseR(on)); }

    // ---- zoom
    bool setZoom(int percent) override
    {
        percent = std::clamp(percent, 0, 100);
        if (zoomSpeed_ > 0) {
            // 100x the magnification, e.g. 100 = 1x, 400 = 4x.
            auto ratio = static_cast<uint32_t>(zoomMin_ + (zoomMax_ - zoomMin_) * percent / 100);
            return ok(dev_->cameraSetZoomWithSpeedAbsoluteR(ratio, static_cast<uint32_t>(zoomSpeed_)));
        }
        return ok(dev_->cameraSetZoomAbsoluteR(1.0f + percent / 100.0f));
    }
    bool setZoomAtSpeed(int percent, int speed) override
    {
        percent = std::clamp(percent, 0, 100);
        auto ratio = static_cast<uint32_t>(zoomMin_ + (zoomMax_ - zoomMin_) * percent / 100);
        return ok(dev_->cameraSetZoomWithSpeedAbsoluteR(ratio, static_cast<uint32_t>(std::clamp(speed, 0, 10))));
    }
    float maxZoom() const override { return zoomMax_ > zoomMin_ ? float(zoomMax_) / 100.0f : 4.0f; }
    bool setZoomSpeed(int speed) override
    {
        zoomSpeed_ = std::clamp(speed, 0, 10);
        return true;
    }

    // ---- image
    bool setFov(Fov fov) override { return ok(dev_->cameraSetFovU(static_cast<Device::FovType>(fov))); }
    bool setHdr(bool on) override
    {
        return ok(dev_->cameraSetWdrR(on ? Device::DevWdrModeDol2TO1 : Device::DevWdrModeNone));
    }
    bool setMirror(bool on) override { return ok(dev_->cameraSetImageFlipHorizonU(on ? 1 : 0)); }
    bool setAutoFocus(bool on) override
    {
        int32_t focus = 0;
        bool af = true;
        dev_->cameraGetFocusAbsolute(focus, af);
        return ok(dev_->cameraSetFocusAbsolute(focus, on));
    }
    bool setManualFocus(int value) override { return ok(dev_->cameraSetFocusAbsolute(std::clamp(value, 0, 100), false)); }
    bool setFaceFocus(bool on) override { return ok(dev_->cameraSetFaceFocusR(on)); }
    bool setFaceExposure(bool on) override { return ok(dev_->cameraSetFaceAER(on ? 1 : 0)); }
    bool setAntiFlicker(int mode) override { return ok(dev_->cameraSetAntiFlickR(std::clamp(mode, 0, 3))); }
    bool setExposure(bool autoExposure, int shutterValue) override
    {
        shutterValue = std::clamp(shutterValue, shutter::First, shutter::Last);
        return ok(dev_->cameraSetExposureAbsolute(shutterValue, autoExposure));
    }
    bool exposure(bool &autoExposure, int &shutterValue) const override
    {
        int32_t v = 0;
        bool a = true;
        if (!ok(dev_->cameraGetExposureAbsolute(v, a))) return false;
        autoExposure = a;
        shutterValue = v;
        return true;
    }
    bool setWhiteBalance(int mode, int kelvin) override
    {
        return ok(dev_->cameraSetWhiteBalanceR(static_cast<Device::DevWhiteBalanceType>(mode), kelvin));
    }
    bool whiteBalance(int &mode, int &kelvin) const override
    {
        Device::DevWhiteBalanceType type{};
        int32_t param = 0;
        if (!ok(dev_->cameraGetWhiteBalanceR(type, param))) return false;
        mode = type;
        kelvin = param;
        return true;
    }
    Range whiteBalanceRange() const override
    {
        Device::UvcParamRange r{};
        return toRange(r, ok(dev_->cameraGetRangeWhiteBalanceR(r)));
    }
    bool setImage(ImageParam p, int v) override
    {
        switch (p) {
        case ImageParam::Brightness: return ok(dev_->cameraSetImageBrightnessR(v));
        case ImageParam::Contrast: return ok(dev_->cameraSetImageContrastR(v));
        case ImageParam::Saturation: return ok(dev_->cameraSetImageSaturationR(v));
        case ImageParam::Sharpness: return ok(dev_->cameraSetImageSharpR(v));
        case ImageParam::Hue: return ok(dev_->cameraSetImageHueR(v));
        }
        return false;
    }
    bool image(ImageParam p, int &v) const override
    {
        int32_t x = 0;
        bool r = false;
        switch (p) {
        case ImageParam::Brightness: r = ok(dev_->cameraGetImageBrightnessR(x)); break;
        case ImageParam::Contrast: r = ok(dev_->cameraGetImageContrastR(x)); break;
        case ImageParam::Saturation: r = ok(dev_->cameraGetImageSaturationR(x)); break;
        case ImageParam::Sharpness: r = ok(dev_->cameraGetImageSharpR(x)); break;
        case ImageParam::Hue: r = ok(dev_->cameraGetImageHueR(x)); break;
        }
        if (r) v = x;
        return r;
    }
    Range imageRange(ImageParam p) const override
    {
        Device::UvcParamRange r{};
        bool got = false;
        switch (p) {
        case ImageParam::Brightness: got = ok(dev_->cameraGetRangeImageBrightnessR(r)); break;
        case ImageParam::Contrast: got = ok(dev_->cameraGetRangeImageContrastR(r)); break;
        case ImageParam::Saturation: got = ok(dev_->cameraGetRangeImageSaturationR(r)); break;
        case ImageParam::Sharpness: got = ok(dev_->cameraGetRangeImageSharpR(r)); break;
        case ImageParam::Hue: got = ok(dev_->cameraGetRangeImageHueR(r)); break;
        }
        return toRange(r, got);
    }

    // ---- audio
    bool setAudioAutoGain(bool on) override { return ok(dev_->cameraSetAudioAutoGainU(on)); }
    bool setVoiceCommand(Voice v, bool on) override
    {
        return ok(dev_->cameraSetAudioCtrlStateU(static_cast<Device::AudioCtrlCmdType>(v), on ? 1 : 0));
    }
    bool setVoiceLanguage(VoiceLanguage lang) override
    {
        return ok(dev_->cameraSetAudioCtrlStateU(Device::AudioCtrlLanguage, static_cast<int32_t>(lang)));
    }

    // ---- presets
    std::vector<Preset> presets() const override
    {
        std::vector<Preset> out;
        Device::DevDataArray ids{};
        if (!ok(dev_->aiGetGimbalPresetListR(&ids))) return out;
        const int n = std::clamp(ids.len, 0, 16);
        for (int i = 0; i < n; ++i) {
            Device::PresetPosInfo info{};
            const int id = ids.data_int32[i];
            if (!ok(dev_->aiGetGimbalPresetInfoWithIdR(&info, id))) continue;
            Preset p;
            p.id = id;
            const int len = std::clamp(info.name_len, 0, static_cast<int>(sizeof(info.name)));
            p.name.assign(info.name, strnlen(info.name, len));
            p.pitch = info.pitch;
            p.yaw = info.yaw;
            p.zoom = info.zoom;
            out.push_back(p);
        }
        std::sort(out.begin(), out.end(), [](const Preset &a, const Preset &b) { return a.id < b.id; });
        return out;
    }
    bool savePreset(int id, const std::string &name) override
    {
        Device::PresetPosInfo info{};
        if (!currentView(info)) return false;
        info.id = id;
        info.name_len = static_cast<int32_t>(std::min(name.size(), sizeof(info.name) - 1));
        std::memcpy(info.name, name.data(), info.name_len);
        return ok(dev_->aiAddGimbalPresetR(&info));
    }
    bool goToPreset(int id) override { return ok(dev_->aiTrgGimbalPresetR(id)); }
    bool deletePreset(int id) override { return ok(dev_->aiDelGimbalPresetR(id)); }
    bool renamePreset(int id, const std::string &name) override
    {
        return ok(dev_->aiSetGimbalPresetNameWithIdR(name, id));
    }

    // ---- device
    bool setGuideLight(bool on) override { return ok(dev_->cameraSetLedCtrlU(on)); }
    bool factoryReset() override { return ok(dev_->cameraSetRestoreFactorySettingsR()); }

private:
    bool currentView(Device::PresetPosInfo &info) const
    {
        Device::AiGimbalStateInfo st{};
        if (!ok(dev_->aiGetGimbalStateR(&st))) return false;
        float zoom = 1.0f;
        dev_->cameraGetZoomAbsoluteR(zoom);
        info.pitch = st.pitch_motor;
        info.yaw = st.yaw_motor;
        info.roll = st.roll_motor;
        info.zoom = zoom;
        info.b_pitch = 0;
        return true;
    }

    std::shared_ptr<Device> dev_;
    std::function<void(const Status &)> statusFn_;
    int zoomSpeed_ = 0;
    long zoomMin_ = 100, zoomMax_ = 400;
};

} // namespace

// ---------------------------------------------------------------- Discovery

bool Discovery::start(ChangeFn fn)
{
    // libdev dereferences a null DIR* if this folder is missing.
    struct stat st{};
    if (stat("/sys/bus/usb/devices", &st) != 0) return false;
    dev_set_log_handler(sdkLog, nullptr);
    {
        std::lock_guard<std::mutex> lock(g_discoveryMutex);
        g_onChange = std::move(fn);
    }
    Devices::get().setDevChangedCallback(
        [](std::string sn, bool in, void *) {
            ChangeFn cb;
            {
                std::lock_guard<std::mutex> lock(g_discoveryMutex);
                cb = g_onChange;
            }
            if (cb) cb(sn, in);
        },
        nullptr);
    Devices::get().setEnableMdnsScan(false); // USB cameras only
    return true;
}

void Discovery::stop()
{
    {
        std::lock_guard<std::mutex> lock(g_discoveryMutex);
        g_onChange = nullptr;
    }
    Devices::get().close();
}

std::vector<std::string> Discovery::cameras()
{
    std::vector<std::string> out;
    for (auto &d : Devices::get().getDevList())
        if (isTiny2Family(d)) out.push_back(d->devSn());
    return out;
}

void Discovery::setVerbose(bool on) { g_verbose = on; }

std::unique_ptr<Camera> openSdkCamera(const std::string &serial)
{
    std::shared_ptr<Device> d;
    if (!serial.empty()) {
        d = Devices::get().getDevBySn(serial);
    } else {
        for (auto &x : Devices::get().getDevList())
            if (isTiny2Family(x)) { d = x; break; }
    }
    if (!isTiny2Family(d)) return nullptr;
    return std::make_unique<SdkCamera>(d);
}

} // namespace t2
