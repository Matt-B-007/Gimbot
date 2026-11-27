#include "controller.hpp"

#include "commands.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QStandardPaths>
#include <QUrl>

#include <algorithm>

using t2::Camera;

namespace {

constexpr int kHoldMs = 1500; // ignore camera echoes this long after a local change

// White balance choices shown in the app, in order.
constexpr int kWbCodes[] = {t2::wb::Auto, t2::wb::Daylight, t2::wb::Cloudy, t2::wb::Tungsten, t2::wb::Fluorescent,
                            t2::wb::Manual};
int wbCode(int index) { return kWbCodes[std::clamp(index, 0, 5)]; }
int wbIndex(int code)
{
    for (int i = 0; i < 6; ++i)
        if (kWbCodes[i] == code) return i;
    return 0;
}

// Startup tracking choices shown in the app, in order.
struct BootChoice { t2::Mode mode; t2::Framing framing; };
constexpr BootChoice kBoot[] = {{t2::Mode::Off, t2::Framing::UpperBody},       {t2::Mode::Person, t2::Framing::UpperBody},
                                {t2::Mode::Person, t2::Framing::FullBody},     {t2::Mode::Person, t2::Framing::CloseUp},
                                {t2::Mode::Group, t2::Framing::UpperBody},     {t2::Mode::Hand, t2::Framing::UpperBody},
                                {t2::Mode::Desk, t2::Framing::UpperBody},      {t2::Mode::Whiteboard, t2::Framing::UpperBody}};
int bootIndexFromMode(int mode)
{
    switch (static_cast<t2::Mode>(mode)) {
    case t2::Mode::Person: return 1;
    case t2::Mode::Group: return 4;
    case t2::Mode::Hand: return 5;
    case t2::Mode::Desk: return 6;
    case t2::Mode::Whiteboard: return 7;
    default: return 0;
    }
}

QVariantMap rangeMap(const t2::Range &r, long fbMin, long fbMax, long fbDef)
{
    return {{"min", qlonglong(r.valid ? r.min : fbMin)},
            {"max", qlonglong(r.valid ? r.max : fbMax)},
            {"def", qlonglong(r.valid ? r.def : fbDef)},
            {"step", qlonglong(r.valid ? r.step : 1)}};
}

QVariantMap statusToMap(const t2::Status &s)
{
    // While the camera switches modes it reports a placeholder; keep showing
    // the previous mode until it settles (items further down still apply).
    QVariantMap m{{"asleep", s.asleep},
                  {"mode", static_cast<int>(s.mode)},
                  {"framing", s.framing},
                  {"zoom", s.zoomPercent},
                  {"hdr", s.hdr},
                  {"fov", s.fov},
                  {"mirrored", s.mirrored},
                  {"autoFocus", s.autoFocus},
                  {"faceFocus", s.faceFocus},
                  {"manualFocus", s.manualFocus},
                  {"faceExposure", s.faceExposure},
                  {"antiFlicker", s.antiFlicker},
                  {"micDuringSleep", s.micDuringSleep},
                  {"voiceLanguage", s.voiceLanguage},
                  {"audioAutoGain", s.audioAutoGain}};
    for (int i = 0; i < static_cast<int>(t2::Voice::Count); ++i)
        m[QStringLiteral("voice%1").arg(i)] = (s.voiceMask & (1 << i)) != 0;
    if (s.modeSwitching) {
        m.remove("mode");
        m.remove("framing");
    }
    return m;
}

// Settings captured by a profile.
const QStringList kProfileKeys = {"mode",        "framing",      "zoom",        "hdr",          "fov",
                                  "mirrored",    "autoFocus",    "faceFocus",   "manualFocus",  "faceExposure",
                                  "antiFlicker", "brightness",   "contrast",    "saturation",   "sharpness",
                                  "hue",         "wbMode",       "wbKelvin",    "exposureAuto", "shutter",
                                  "trackStyle",  "autoZoom",     "zoneEnabled", "zoneYawMin",   "zoneYawMax",
                                  "zonePitchMin", "zonePitchMax", "zoneAutoSelect"};

// Setting one key implies another (e.g. moving the focus slider means manual focus).
const QHash<QString, QPair<QString, QVariant>> kImplies = {{"framing", {"mode", 2}},
                                                           {"manualFocus", {"autoFocus", false}},
                                                           {"wbKelvin", {"wbMode", 5}},
                                                           {"shutter", {"exposureAuto", false}}};

} // namespace

Controller::Controller(bool simulated, QObject *parent) : QObject(parent), m_simulated(simulated)
{
    defineSettings();
    for (auto it = m_table.cbegin(); it != m_table.cend(); ++it) {
        const bool persisted = it->kind == Kind::Pushed || it->kind == Kind::App;
        m_values[it.key()] = persisted ? m_settings.value("settings/" + it.key(), it->def) : it->def;
        // QSettings returns strings for some types; keep the default's type.
        m_values[it.key()].convert(it->def.metaType());
    }
    m_ranges = {{"brightness", rangeMap({}, 0, 100, 50)}, {"contrast", rangeMap({}, 0, 100, 50)},
                {"saturation", rangeMap({}, 0, 100, 50)}, {"sharpness", rangeMap({}, 0, 100, 50)},
                {"hue", rangeMap({}, 0, 100, 50)},        {"wb", rangeMap({}, 2000, 10000, 5000)}};

    m_positionTimer.setInterval(350);
    connect(&m_positionTimer, &QTimer::timeout, this, &Controller::pollPosition);
    m_guideLightTimer.setSingleShot(true);
    m_guideLightTimer.setInterval(4000);
    connect(&m_guideLightTimer, &QTimer::timeout, this,
            [this] { call("guide", tr("the guide light"), [](Camera &c) { return c.setGuideLight(false); }); });
    m_resumeTimer.setSingleShot(true);
    connect(&m_resumeTimer, &QTimer::timeout, this, [this] {
        if (m_trackingPaused && m_values["autoResume"].toBool()) resumeTracking();
    });
}

Controller::~Controller()
{
    if (!m_simulated) t2::Discovery::stop();
    // Release the camera on its own thread, and wait for that before any
    // member is destroyed (m_cam is destroyed before m_worker otherwise,
    // racing the worker and crashing on quit).
    m_worker.post([this] { m_cam.reset(); });
    m_worker.stop();
}

// ---------------------------------------------------------------- settings table

void Controller::def(const QString &key, Kind kind, const QVariant &d, const QString &label, Apply apply)
{
    m_table.insert(key, {kind, d, label, std::move(apply)});
}

void Controller::defineSettings()
{
    using V = const QVariantMap &;
    auto b = [](V v, const char *k) { return v.value(k).toBool(); };
    auto i = [](V v, const char *k) { return v.value(k).toInt(); };

    // Reported continuously by the camera.
    def("asleep", Kind::Status, false, tr("sleep"), [=](Camera &c, V v) { return c.setAsleep(b(v, "asleep")); });
    def("mode", Kind::Status, 2, tr("tracking"), [=](Camera &c, V v) {
        return c.setMode(static_cast<t2::Mode>(i(v, "mode")), static_cast<t2::Framing>(i(v, "framing")));
    });
    def("framing", Kind::Status, 1, tr("framing"), [=](Camera &c, V v) {
        return c.setMode(t2::Mode::Person, static_cast<t2::Framing>(i(v, "framing")));
    });
    def("zoom", Kind::Status, 0, tr("zoom"), [=](Camera &c, V v) { return c.setZoom(i(v, "zoom")); });
    def("hdr", Kind::Status, false, tr("HDR"), [=](Camera &c, V v) { return c.setHdr(b(v, "hdr")); });
    def("fov", Kind::Status, 0, tr("field of view"),
        [=](Camera &c, V v) { return c.setFov(static_cast<t2::Fov>(i(v, "fov"))); });
    def("mirrored", Kind::Status, false, tr("mirroring"), [=](Camera &c, V v) { return c.setMirror(b(v, "mirrored")); });
    def("autoFocus", Kind::Status, true, tr("focus"), [=](Camera &c, V v) {
        return b(v, "autoFocus") ? c.setAutoFocus(true) : c.setManualFocus(i(v, "manualFocus"));
    });
    def("manualFocus", Kind::Status, 50, tr("focus"),
        [=](Camera &c, V v) { return c.setManualFocus(i(v, "manualFocus")); });
    def("faceFocus", Kind::Status, false, tr("face focus"),
        [=](Camera &c, V v) { return c.setFaceFocus(b(v, "faceFocus")); });
    def("faceExposure", Kind::Status, false, tr("face exposure"),
        [=](Camera &c, V v) { return c.setFaceExposure(b(v, "faceExposure")); });
    def("antiFlicker", Kind::Status, 3, tr("anti-flicker"),
        [=](Camera &c, V v) { return c.setAntiFlicker(i(v, "antiFlicker")); });
    def("micDuringSleep", Kind::Status, false, tr("microphone during sleep"),
        [=](Camera &c, V v) { return c.setMicDuringSleep(b(v, "micDuringSleep")); });
    def("voiceLanguage", Kind::Status, 1, tr("voice language"), [=](Camera &c, V v) {
        return c.setVoiceLanguage(static_cast<t2::VoiceLanguage>(i(v, "voiceLanguage")));
    });
    def("audioAutoGain", Kind::Status, true, tr("automatic mic volume"),
        [=](Camera &c, V v) { return c.setAudioAutoGain(b(v, "audioAutoGain")); });
    for (int n = 0; n < static_cast<int>(t2::Voice::Count); ++n) {
        const QString key = QStringLiteral("voice%1").arg(n);
        def(key, Kind::Status, true, tr("voice commands"), [n, key](Camera &c, V v) {
            return c.setVoiceCommand(static_cast<t2::Voice>(n), v.value(key).toBool());
        });
    }

    // Read from the camera when it connects.
    def("bootMode", Kind::Read, 1, tr("startup tracking mode"), [=](Camera &c, V v) {
        const auto &bc = kBoot[std::clamp(i(v, "bootMode"), 0, 7)];
        return c.setBootMode(bc.mode, bc.framing);
    });
    auto image = [=, this](const char *key, t2::ImageParam p) {
        def(key, Kind::Read, 50, tr("image settings"), [=](Camera &c, V v) { return c.setImage(p, i(v, key)); });
    };
    image("brightness", t2::ImageParam::Brightness);
    image("contrast", t2::ImageParam::Contrast);
    image("saturation", t2::ImageParam::Saturation);
    image("sharpness", t2::ImageParam::Sharpness);
    image("hue", t2::ImageParam::Hue);
    auto wbApply = [=](Camera &c, V v) { return c.setWhiteBalance(wbCode(i(v, "wbMode")), i(v, "wbKelvin")); };
    def("wbMode", Kind::Read, 0, tr("white balance"), wbApply);
    def("wbKelvin", Kind::Read, 5000, tr("white balance"), wbApply);
    auto expApply = [=](Camera &c, V v) { return c.setExposure(b(v, "exposureAuto"), i(v, "shutter")); };
    def("exposureAuto", Kind::Read, true, tr("exposure"), expApply);
    def("shutter", Kind::Read, 30, tr("exposure"), expApply);
    def("zoneEnabled", Kind::Read, false, tr("tracking area"),
        [=](Camera &c, V v) { return c.setZoneEnabled(b(v, "zoneEnabled")); });
    auto zoneApply = [](Camera &c, V v) {
        return c.setZone({v.value("zoneYawMin").toFloat(), v.value("zoneYawMax").toFloat(),
                          v.value("zonePitchMin").toFloat(), v.value("zonePitchMax").toFloat()});
    };
    def("zoneYawMin", Kind::Read, -60.0, tr("tracking area"), zoneApply);
    def("zoneYawMax", Kind::Read, 60.0, tr("tracking area"), zoneApply);
    def("zonePitchMin", Kind::Read, -30.0, tr("tracking area"), zoneApply);
    def("zonePitchMax", Kind::Read, 30.0, tr("tracking area"), zoneApply);
    def("zoneAutoSelect", Kind::Read, true, tr("automatic target"),
        [=](Camera &c, V v) { return c.setZoneAutoSelect(b(v, "zoneAutoSelect")); });

    // Remembered by Gimbot and sent to the camera when it connects (the
    // camera can't report these back).
    def("trackStyle", Kind::Pushed, 0, tr("tracking style"),
        [=](Camera &c, V v) { return c.setTrackStyle(static_cast<t2::TrackStyle>(i(v, "trackStyle"))); });
    def("autoZoom", Kind::Pushed, true, tr("auto zoom"), [=](Camera &c, V v) { return c.setAutoZoom(b(v, "autoZoom")); });
    def("gestureSelect", Kind::Pushed, true, tr("gestures"),
        [=](Camera &c, V v) { return c.setGesture(0, b(v, "gestureSelect")); });
    def("gestureZoom", Kind::Pushed, true, tr("gestures"),
        [=](Camera &c, V v) { return c.setGesture(1, b(v, "gestureZoom")); });
    def("gestureDynamic", Kind::Pushed, false, tr("gestures"),
        [=](Camera &c, V v) { return c.setGesture(2, b(v, "gestureDynamic")); });
    def("gestureReverse", Kind::Pushed, false, tr("gestures"),
        [=](Camera &c, V v) { return c.setGesture(3, b(v, "gestureReverse")); });
    def("yawReverse", Kind::Pushed, false, tr("pan direction"),
        [=](Camera &c, V v) { return c.setYawReverse(b(v, "yawReverse")); });
    def("zoomSpeed", Kind::Pushed, 0, tr("zoom speed"), [=](Camera &c, V v) { return c.setZoomSpeed(i(v, "zoomSpeed")); });
    def("sleepTimer", Kind::Pushed, 0, tr("sleep timer"),
        [=](Camera &c, V v) { return c.setSleepTimer(i(v, "sleepTimer")); });

    // Gimbot's own preferences.
    def("invertPan", Kind::App, false, {});
    def("invertTilt", Kind::App, false, {});
    def("smoothness", Kind::App, 1, {});        // t2::Smoothness
    def("lastTrackingMode", Kind::App, 2, {});  // mode the tracking switch turns on
    def("autoResume", Kind::App, false, {});    // resume tracking after a manual move
    def("autoResumeSeconds", Kind::App, 5, {});
    def("previewChoice", Kind::App, QString(), {}); // "" auto, or e.g. "1920x1080@60"
    def("tourDone", Kind::App, false, {});
    def("startupPreset", Kind::App, -2, {});   // -2 not chosen here, -1 straight ahead, else preset id
    def("moreAim", Kind::App, false, {});      // "More" sections on the main screen
    def("moreTracking", Kind::App, false, {});
    def("moreImage", Kind::App, false, {});
    def("gimbalSpeed", Kind::App, 60, {});
    def("guideLight", Kind::App, true, {});
    def("closeToTray", Kind::App, true, {});
    def("autostart", Kind::App, false, {});
    def("updateChannel", Kind::App, 1, {}); // 0 off, 1 stable, 2 beta
    def("verboseLogging", Kind::App, false, {});
    def("previewEnabled", Kind::App, true, {});
    def("showGrid", Kind::App, true, {});
    def("theme", Kind::App, 0, {}); // 0 follow system, 1 dark, 2 light
    def("systemAccent", Kind::App, false, {});
}

// ---------------------------------------------------------------- plumbing

void Controller::call(const QString &key, const QString &what, std::function<bool(Camera &)> fn, bool latest)
{
    if (!m_connected) return;
    auto job = [this, what, fn] {
        if (!m_cam) return;
        if (!fn(*m_cam))
            QMetaObject::invokeMethod(
                this, [this, what] { emit errorOccurred(tr("The camera didn't accept the change to %1.").arg(what)); });
    };
    if (latest) m_worker.postLatest(key, job);
    else m_worker.post(job);
}

void Controller::touch(const QString &key) { m_touched[key].start(); }

bool Controller::held(const QString &key) const
{
    auto it = m_touched.constFind(key);
    return it != m_touched.cend() && it->isValid() && it->elapsed() < kHoldMs;
}

void Controller::set(const QString &key, const QVariant &value)
{
    auto it = m_table.constFind(key);
    if (it == m_table.cend()) {
        qWarning() << "Unknown setting" << key;
        return;
    }
    QVariant v = value;
    v.convert(it->def.metaType());
    const auto implied = kImplies.value(key);
    if (m_values.value(key) == v && (implied.first.isEmpty() || m_values.value(implied.first) == implied.second)) return;

    m_values[key] = v;
    touch(key);
    if (!implied.first.isEmpty()) {
        m_values[implied.first] = implied.second;
        touch(implied.first);
    }
    if (key == "mode") touch("framing");

    if ((key == "mode" || implied.first == "mode") && !m_internalSet) {
        // The user chose a mode (or turned tracking off) themselves.
        setPaused(false);
        const int mode = m_values["mode"].toInt();
        if (mode != 0 && m_values["lastTrackingMode"].toInt() != mode) {
            m_values["lastTrackingMode"] = mode;
            m_settings.setValue("settings/lastTrackingMode", mode);
        }
    }
    if (!m_activeProfile.isEmpty() && !m_internalSet && kProfileKeys.contains(key)) {
        m_activeProfile.clear();
        emit activeProfileChanged();
    }
    emit valuesChanged();
    if (key == "mirrored" || key == "invertPan" || key == "invertTilt") emit positionChanged();

    if (it->kind == Kind::Pushed || it->kind == Kind::App) m_settings.setValue("settings/" + key, v);
    if (it->kind == Kind::App) emit appSettingChanged(key, v);
    if (key.startsWith("zone") && key != "zoneEnabled" && key != "zoneAutoSelect" && m_values["guideLight"].toBool()) {
        // Light the camera's guide pattern while the area is being adjusted.
        if (!m_guideLightTimer.isActive())
            call("guide", tr("the guide light"), [](Camera &c) { return c.setGuideLight(true); });
        m_guideLightTimer.start();
    }
    sendToCamera(key);
}

void Controller::sendToCamera(const QString &key)
{
    const auto &s = m_table[key];
    if (!s.apply) return;
    const QVariantMap snapshot = m_values;
    // Keys that share one camera call also share a queue slot.
    QString slot = key;
    if (key.startsWith("zoneYaw") || key.startsWith("zonePitch")) slot = "zoneLimits";
    else if (key == "wbMode" || key == "wbKelvin") slot = "wb";
    else if (key == "exposureAuto" || key == "shutter") slot = "exposure";
    else if (key == "mode" || key == "framing") slot = "mode";
    else if (key == "autoFocus" || key == "manualFocus") slot = "focus";
    auto apply = s.apply;
    call(slot, s.label, [apply, snapshot](Camera &c) { return apply(c, snapshot); });
}

void Controller::applyStatus(const t2::Status &s)
{
    if (!s.valid) return;
    mergeFromCamera(statusToMap(s), false);
}

void Controller::mergeFromCamera(const QVariantMap &v, bool includeBootMode)
{
    bool changed = false;
    for (auto it = v.cbegin(); it != v.cend(); ++it) {
        if (!m_table.contains(it.key()) || held(it.key())) continue;
        if (it.key() == "bootMode" && !includeBootMode) continue;
        QVariant val = it.value();
        val.convert(m_table[it.key()].def.metaType());
        if (m_values.value(it.key()) != val) {
            m_values[it.key()] = val;
            changed = true;
            if (it.key() == "mirrored") emit positionChanged();
            if (it.key() == "mode" && val.toInt() != 0) {
                // Tracking started on the camera (a gesture, a voice command…).
                setPaused(false);
                m_values["lastTrackingMode"] = val;
                m_settings.setValue("settings/lastTrackingMode", val);
            }
        }
    }
    if (changed) emit valuesChanged();
}

QVariantMap Controller::gatherAll(Camera &cam) const
{
    QVariantMap v = statusToMap(cam.status());
    v["bootMode"] = bootIndexFromMode(cam.status().bootMode);
    static const std::pair<const char *, t2::ImageParam> params[] = {{"brightness", t2::ImageParam::Brightness},
                                                                     {"contrast", t2::ImageParam::Contrast},
                                                                     {"saturation", t2::ImageParam::Saturation},
                                                                     {"sharpness", t2::ImageParam::Sharpness},
                                                                     {"hue", t2::ImageParam::Hue}};
    QVariantMap ranges;
    for (auto &p : params) {
        int x = 0;
        if (cam.image(p.second, x)) v[p.first] = x;
        ranges[p.first] = rangeMap(cam.imageRange(p.second), 0, 100, 50);
    }
    ranges["wb"] = rangeMap(cam.whiteBalanceRange(), 2000, 10000, 5000);
    ranges["zoomMax"] = double(cam.maxZoom());
    v["_ranges"] = ranges;
    int wbMode = 0, kelvin = 5000;
    if (cam.whiteBalance(wbMode, kelvin)) {
        v["wbMode"] = wbIndex(wbMode);
        if (kelvin > 0) v["wbKelvin"] = kelvin;
    }
    bool ae = true;
    int sh = 30;
    if (cam.exposure(ae, sh)) {
        v["exposureAuto"] = ae;
        if (sh >= t2::shutter::First && sh <= t2::shutter::Last) v["shutter"] = sh;
    }
    bool on = false;
    if (cam.zoneEnabled(on)) v["zoneEnabled"] = on;
    if (cam.zoneAutoSelect(on)) v["zoneAutoSelect"] = on;
    t2::Zone z;
    if (cam.zone(z)) {
        v["zoneYawMin"] = double(z.yawMin);
        v["zoneYawMax"] = double(z.yawMax);
        v["zonePitchMin"] = double(z.pitchMin);
        v["zonePitchMax"] = double(z.pitchMax);
    }
    return v;
}

// ---------------------------------------------------------------- connection

void Controller::start()
{
    if (m_simulated) {
        tryOpen(QString());
        return;
    }
    m_usbAvailable = t2::Discovery::start([this](const std::string &sn, bool in) {
        const QString serial = QString::fromStdString(sn);
        QMetaObject::invokeMethod(this, [this, serial, in] { onHotplug(serial, in); }, Qt::QueuedConnection);
    });
    if (!m_usbAvailable) {
        qWarning() << "No USB bus found; camera detection is disabled";
        emit deviceChanged();
        return;
    }
    // Retry in case the plug-in event for an already-connected camera was missed.
    auto *retry = new QTimer(this);
    retry->setInterval(4000);
    connect(retry, &QTimer::timeout, this, [this] {
        if (!m_connected) tryOpen(QString());
    });
    retry->start();
}

void Controller::onHotplug(const QString &serial, bool in)
{
    qInfo() << "Camera" << serial << (in ? "connected" : "disconnected");
    if (in) {
        if (!m_connected) tryOpen(serial);
        return;
    }
    if (serial != m_serial) return;
    m_connected = false;
    m_serial.clear();
    m_worker.post([this] { m_cam.reset(); });
    emit connectedChanged();
    emit deviceChanged();
    emit notice(tr("Camera disconnected"));
}

void Controller::tryOpen(const QString &serial)
{
    if (m_opening) return;
    m_opening = true;
    const QVariantMap pushed = m_values;
    QList<Apply> pushes;
    for (auto it = m_table.cbegin(); it != m_table.cend(); ++it)
        if (it->kind == Kind::Pushed) pushes << it->apply;
    const bool sim = m_simulated;

    m_worker.post([=, this] {
        auto cam = sim ? t2::openFakeCamera() : t2::openSdkCamera(serial.toStdString());
        if (!cam) {
            QMetaObject::invokeMethod(this, [this] { m_opening = false; });
            return;
        }
        const QString model = QString::fromStdString(cam->model());
        const QString sn = QString::fromStdString(cam->serial());
        const QString fw = QString::fromStdString(cam->firmware());
        const QVariantMap all = gatherAll(*cam);
        const auto presets = cam->presets();
        for (const auto &apply : pushes) apply(*cam, pushed);
        cam->onStatus([this](const t2::Status &s) {
            QMetaObject::invokeMethod(this, [this, s] { applyStatus(s); }, Qt::QueuedConnection);
        });
        m_cam = std::move(cam);

        QMetaObject::invokeMethod(this, [=, this] {
            m_opening = false;
            m_model = model;
            m_serial = sn;
            m_firmware = fw;
            m_ranges = all.value("_ranges").toMap();
            m_touched.clear();
            mergeFromCamera(all, true);
            m_connected = true;
            buildPresetList(presets);
            qInfo() << "Opened" << model << sn << "firmware" << fw;
            emit deviceChanged();
            emit rangesChanged();
            emit connectedChanged();
            if (m_livePosition) m_positionTimer.start();
        });
    });
}

void Controller::runCommand(const QStringList &args, std::function<void(int, QString)> reply)
{
    std::vector<std::string> a;
    for (const auto &s : args) a.push_back(s.toStdString());
    m_worker.post([this, a, reply] {
        if (!m_cam) {
            QMetaObject::invokeMethod(this, [reply] { reply(1, QStringLiteral("no camera connected\n")); });
            return;
        }
        std::string out;
        const int code = t2::runCommand(*m_cam, a, out);
        const QVariantMap all = gatherAll(*m_cam);
        const auto presets = m_cam->presets();
        QMetaObject::invokeMethod(this, [=, this] {
            mergeFromCamera(all, true);
            buildPresetList(presets);
            reply(code, QString::fromStdString(out));
        });
    });
}

// ---------------------------------------------------------------- gimbal

void Controller::setLivePosition(bool on)
{
    if (m_livePosition == on) return;
    m_livePosition = on;
    if (on && m_connected) m_positionTimer.start();
    else m_positionTimer.stop();
    emit livePositionChanged();
}

void Controller::pollPosition()
{
    if (!m_connected || m_positionPending) return;
    m_positionPending = true;
    m_worker.post([this] {
        t2::GimbalPos p;
        const bool ok = m_cam && m_cam->position(p);
        QMetaObject::invokeMethod(this, [this, ok, p] {
            m_positionPending = false;
            if (!ok) return;
            if (!qFuzzyCompare(m_yaw + 1000, p.yaw + 1000.0) || !qFuzzyCompare(m_pitch + 1000, p.pitch + 1000.0)) {
                m_yaw = p.yaw;
                m_pitch = p.pitch;
                emit positionChanged();
            }
        });
    });
}

t2::axis::Orientation Controller::orientation() const
{
    t2::axis::Orientation o;
    o.mirrored = m_values["mirrored"].toBool();
    o.invertPan = m_values["invertPan"].toBool();
    o.invertTilt = m_values["invertTilt"].toBool();
    return o;
}

double Controller::pan() const { return t2::axis::screenFromYaw(m_yaw, orientation()); }
double Controller::tilt() const { return t2::axis::screenFromPitch(m_pitch, orientation()); }

float Controller::glide() const
{
    return t2::glideSpeed(static_cast<t2::Smoothness>(std::clamp(m_values["smoothness"].toInt(), 0, 3)));
}

void Controller::setPaused(bool on)
{
    if (!on) m_resumeTimer.stop();
    if (m_trackingPaused == on) return;
    m_trackingPaused = on;
    emit trackingPausedChanged();
}

void Controller::leaveTracking()
{
    // AI tracking owns the gimbal; a manual move pauses it. The switch on the
    // main screen shows it off, with a Resume button next to it.
    if (m_values["mode"].toInt() != 0) {
        m_internalSet = true;
        set("mode", 0);
        m_internalSet = false;
        setPaused(true);
    }
    if (m_trackingPaused && m_values["autoResume"].toBool())
        m_resumeTimer.start(std::clamp(m_values["autoResumeSeconds"].toInt(), 1, 60) * 1000);
}

void Controller::toggleTracking() { setTracking(m_values["mode"].toInt() == 0); }

void Controller::setTracking(bool on)
{
    if (!on) setPaused(false); // switched off on purpose, even if it already was
    const int last = m_values["lastTrackingMode"].toInt();
    set("mode", on ? (last >= 1 && last <= 5 ? last : 2) : 0);
}

void Controller::resumeTracking() { setTracking(true); }

void Controller::move(double tilt, double pan)
{
    leaveTracking();
    const double speed = m_values["gimbalSpeed"].toDouble();
    const auto o = orientation();
    const double pitch = t2::axis::pitchFromScreen(std::clamp(tilt, -1.0, 1.0) * speed, o);
    const double yaw = t2::axis::yawFromScreen(std::clamp(pan, -1.0, 1.0) * speed, o);
    call("move", tr("the gimbal"), [pitch, yaw](Camera &c) { return c.move(pitch, yaw); });
}

void Controller::nudge(double tilt, double pan)
{
    move(tilt, pan);
    QTimer::singleShot(600, this, [this] { stopMove(); });
}

void Controller::stopMove()
{
    call("move", tr("the gimbal"), [](Camera &c) { return c.move(0, 0); });
    if (m_trackingPaused && m_values["autoResume"].toBool())
        m_resumeTimer.start(std::clamp(m_values["autoResumeSeconds"].toInt(), 1, 60) * 1000);
}

void Controller::recenter()
{
    leaveTracking();
    const float speed = glide();
    m_yaw = m_pitch = 0;
    emit positionChanged();
    call("move", tr("recentering"), [speed](Camera &c) { return speed > 0 ? c.moveTo(0, 0, speed) : c.recenter(); });
}

void Controller::aimAt(double x, double y)
{
    leaveTracking();
    const auto o = orientation();
    const float speed = glide();
    call("move", tr("aiming"), [x, y, o, speed](Camera &c) { return c.aimAt(x, y, o, speed); });
}

void Controller::aimAbsolute(double pan, double tilt)
{
    leaveTracking();
    const auto o = orientation();
    m_yaw = t2::axis::yawFromScreen(pan, o);
    m_pitch = t2::axis::pitchFromScreen(tilt, o);
    emit positionChanged();
    const float pitch = float(m_pitch), yaw = float(m_yaw), speed = glide();
    call("move", tr("aiming"), [pitch, yaw, speed](Camera &c) { return c.moveTo(pitch, yaw, speed); });
}

void Controller::zoomBy(int delta) { set("zoom", std::clamp(m_values["zoom"].toInt() + delta, 0, 100)); }

// ---------------------------------------------------------------- presets

QString Controller::thumbnailPath(int id) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/thumbnails";
    QDir().mkpath(dir);
    return dir + QStringLiteral("/%1-%2.png").arg(m_serial.isEmpty() ? QStringLiteral("camera") : m_serial).arg(id);
}

void Controller::thumbnailSaved(int id)
{
    m_thumbRev[id] += 1;
    buildPresetList(m_rawPresets);
}

void Controller::buildPresetList(const std::vector<t2::Preset> &list)
{
    // Show presets in the order the user arranged (kept per camera); new
    // ones go at the end.
    const QVariantList order = m_settings.value("presetOrder/" + (m_serial.isEmpty() ? QStringLiteral("camera") : m_serial)).toList();
    auto rank = [&](int id) {
        const int i = order.indexOf(id);
        return i < 0 ? 1000 + id : i;
    };
    std::vector<t2::Preset> sorted = list;
    std::stable_sort(sorted.begin(), sorted.end(), [&](const t2::Preset &a, const t2::Preset &b) { return rank(a.id) < rank(b.id); });
    m_rawPresets = sorted;
    const auto &listInOrder = m_rawPresets;
    m_presets.clear();
    int index = 0;
    for (const auto &p : listInOrder) {
        const QString name = QString::fromStdString(p.name);
        const QString path = thumbnailPath(p.id);
        m_presets.append(QVariantMap{
            {"id", p.id},
            {"index", index++},
            {"name", name.isEmpty() ? tr("Preset %1").arg(p.id + 1) : name},
            {"thumbnail", QFileInfo::exists(path)
                              ? QUrl::fromLocalFile(path).toString() + QStringLiteral("?r=%1").arg(m_thumbRev.value(p.id))
                              : QString()}});
    }
    emit presetsChanged();
}

void Controller::reloadPresets()
{
    m_worker.post([this] {
        if (!m_cam) return;
        auto list = m_cam->presets();
        QMetaObject::invokeMethod(this, [this, list] { buildPresetList(list); });
    });
}

int Controller::savePreset(const QString &name)
{
    if (!m_connected) return -1;
    int id = -1;
    for (int n = 0; n < maxPresets() && id < 0; ++n)
        if (std::none_of(m_rawPresets.begin(), m_rawPresets.end(), [n](const t2::Preset &p) { return p.id == n; }))
            id = n;
    if (id < 0) {
        emit errorOccurred(tr("All %1 preset slots are in use. Delete one first.").arg(maxPresets()));
        return -1;
    }
    t2::Preset p;
    p.id = id;
    p.name = name.toStdString();
    m_rawPresets.push_back(p);
    std::sort(m_rawPresets.begin(), m_rawPresets.end(), [](const t2::Preset &a, const t2::Preset &b) { return a.id < b.id; });
    buildPresetList(m_rawPresets);
    const std::string n = name.toStdString();
    call("preset", tr("the preset"), [id, n](Camera &c) { return c.savePreset(id, n); }, false);
    reloadPresets();
    return id;
}

void Controller::updatePreset(int id)
{
    std::string name;
    for (const auto &p : m_rawPresets)
        if (p.id == id) name = p.name;
    call("preset", tr("the preset"), [id, name](Camera &c) { return c.savePreset(id, name); }, false);
    reloadPresets();
    emit notice(tr("Preset updated to the current view"));
}

void Controller::goToPreset(int id)
{
    leaveTracking();
    const auto level = static_cast<t2::Smoothness>(std::clamp(m_values["smoothness"].toInt(), 0, 3));
    const float speed = t2::glideSpeed(level);
    const int zoomSpeed = t2::glideZoomSpeed(level);
    call("move", tr("the preset"), [id, speed, zoomSpeed](Camera &c) { return c.glideToPreset(id, speed, zoomSpeed); });
}

void Controller::goToPresetIndex(int index)
{
    if (index >= 0 && index < int(m_rawPresets.size())) goToPreset(m_rawPresets[index].id);
}

void Controller::movePreset(int id, int toIndex)
{
    QVariantList ids;
    for (const auto &p : m_rawPresets) ids << p.id;
    const int from = ids.indexOf(id);
    toIndex = std::clamp(toIndex, 0, int(ids.size()) - 1);
    if (from < 0 || from == toIndex) return;
    ids.move(from, toIndex);
    m_settings.setValue("presetOrder/" + (m_serial.isEmpty() ? QStringLiteral("camera") : m_serial), ids);
    buildPresetList(m_rawPresets);
}

void Controller::setStartupPreset(int id)
{
    // -1: straight ahead. Otherwise go to the preset, then save where the
    // camera is as its start position (the camera keeps one position).
    m_values["startupPreset"] = id;
    m_settings.setValue("settings/startupPreset", id);
    emit valuesChanged();
    if (id < 0) {
        startup("reset");
        emit notice(tr("The camera will start pointing straight ahead"));
        return;
    }
    leaveTracking();
    call("move", tr("the preset"), [id](Camera &c) { return c.goToPreset(id); });
    QTimer::singleShot(3000, this, [this] {
        call("startup", tr("the start position"), [](Camera &c) { return c.bootUseCurrent(); }, false);
    });
    for (const auto &p : m_rawPresets)
        if (p.id == id) emit notice(tr("The camera will start at “%1”").arg(QString::fromStdString(p.name)));
}

void Controller::renamePreset(int id, const QString &name)
{
    for (auto &p : m_rawPresets)
        if (p.id == id) p.name = name.toStdString();
    buildPresetList(m_rawPresets);
    const std::string n = name.toStdString();
    call("preset", tr("the preset name"), [id, n](Camera &c) { return c.renamePreset(id, n); }, false);
}

void Controller::deletePreset(int id)
{
    m_rawPresets.erase(std::remove_if(m_rawPresets.begin(), m_rawPresets.end(),
                                      [id](const t2::Preset &p) { return p.id == id; }),
                       m_rawPresets.end());
    buildPresetList(m_rawPresets);
    QFile::remove(thumbnailPath(id));
    call("preset", tr("deleting the preset"), [id](Camera &c) { return c.deletePreset(id); }, false);
    reloadPresets();
}

// ---------------------------------------------------------------- actions

void Controller::zoneStart(const QString &action)
{
    if (action == "use-current") {
        call("zoneStart", tr("the area's starting position"), [](Camera &c) { return c.zoneStartUseCurrent(); }, false);
        emit notice(tr("Starting position saved"));
    } else if (action == "go") {
        leaveTracking();
        call("move", tr("the area's starting position"), [](Camera &c) { return c.zoneStartGo(); });
    } else if (action == "reset") {
        call("zoneStart", tr("the area's starting position"), [](Camera &c) { return c.zoneStartReset(); }, false);
    }
}

void Controller::resetZone()
{
    m_worker.post([this] {
        if (!m_cam) return;
        const bool ok = m_cam->resetZone();
        t2::Zone z;
        const bool got = m_cam->zone(z);
        QMetaObject::invokeMethod(this, [=, this] {
            if (!ok) emit errorOccurred(tr("The camera didn't reset the tracking area."));
            if (got)
                mergeFromCamera({{"zoneYawMin", double(z.yawMin)}, {"zoneYawMax", double(z.yawMax)},
                                 {"zonePitchMin", double(z.pitchMin)}, {"zonePitchMax", double(z.pitchMax)}},
                                false);
        });
    });
}

void Controller::startup(const QString &action)
{
    if (action == "use-current") {
        call("startup", tr("the start position"), [](Camera &c) { return c.bootUseCurrent(); }, false);
        emit notice(tr("Start position saved"));
    } else if (action == "go") {
        leaveTracking();
        call("move", tr("the start position"), [](Camera &c) { return c.bootGo(); });
    } else if (action == "reset") {
        call("startup", tr("the start position"), [](Camera &c) { return c.bootReset(); }, false);
    }
}

void Controller::snapshotForUndo(const QStringList &keys, const QString &message)
{
    m_undo.clear();
    m_undoProfile.clear();
    for (const auto &k : keys) m_undo[k] = m_values.value(k);
    emit undoAvailable(message);
}

void Controller::undo()
{
    if (!m_undoProfile.isEmpty()) {
        m_settings.setValue("profiles/" + m_undoProfile, m_undoProfileData);
        m_undoProfile.clear();
        emit profilesChanged();
        return;
    }
    const QVariantMap restore = m_undo;
    m_undo.clear();
    // Mode last, as when applying a profile.
    for (auto it = restore.cbegin(); it != restore.cend(); ++it)
        if (it.key() != "mode") set(it.key(), it.value());
    if (restore.contains("mode")) set("mode", restore.value("mode"));
}

void Controller::resetImage()
{
    snapshotForUndo({"brightness", "contrast", "saturation", "sharpness", "hue", "wbMode", "wbKelvin", "exposureAuto",
                     "shutter", "hdr", "faceExposure", "autoFocus", "manualFocus"},
                    tr("Image settings reset"));
    for (const char *k : {"brightness", "contrast", "saturation", "sharpness", "hue"})
        set(k, m_ranges.value(k).toMap().value("def").toInt());
    set("wbMode", 0);
    set("exposureAuto", true);
    set("hdr", false);
    set("faceExposure", false);
    set("autoFocus", true);
}

void Controller::resetTracking()
{
    snapshotForUndo({"framing", "trackStyle", "fov", "autoZoom"}, tr("Tracking settings reset"));
    m_internalSet = true; // keep tracking as it is
    if (m_values["mode"].toInt() == 2) set("framing", 1);
    else m_values["framing"] = 1;
    m_internalSet = false;
    set("trackStyle", 0);
    set("fov", 0);
    set("autoZoom", true);
    emit valuesChanged();
}

void Controller::factoryReset()
{
    m_worker.post([this] {
        if (!m_cam) return;
        const bool ok = m_cam->factoryReset();
        const QVariantMap all = gatherAll(*m_cam);
        const auto presets = m_cam->presets();
        QMetaObject::invokeMethod(this, [=, this] {
            if (!ok) {
                emit errorOccurred(tr("The camera didn't accept the factory reset."));
                return;
            }
            m_touched.clear();
            mergeFromCamera(all, true);
            buildPresetList(presets);
            emit notice(tr("Camera reset to factory settings"));
        });
    });
}

// ---------------------------------------------------------------- profiles

QStringList Controller::profiles() const
{
    QSettings s;
    s.beginGroup("profiles");
    QStringList names = s.childKeys();
    names.sort(Qt::CaseInsensitive);
    return names;
}

void Controller::saveProfile(const QString &name)
{
    if (name.trimmed().isEmpty()) return;
    QVariantMap snap;
    for (const auto &k : kProfileKeys) snap[k] = m_values.value(k);
    m_settings.setValue("profiles/" + name.trimmed(), snap);
    emit profilesChanged();
    emit notice(tr("Saved profile “%1”").arg(name.trimmed()));
}

void Controller::applyProfile(const QString &name)
{
    const QVariantMap snap = m_settings.value("profiles/" + name).toMap();
    if (snap.isEmpty()) return;
    snapshotForUndo(kProfileKeys, tr("Applied profile “%1”").arg(name));
    // Mode last, so framing doesn't switch tracking on when the profile has it off.
    for (const auto &k : kProfileKeys)
        if (k != "mode" && snap.contains(k)) set(k, snap.value(k));
    if (snap.contains("mode")) set("mode", snap.value("mode"));
    m_activeProfile = name;
    emit activeProfileChanged();
}

void Controller::deleteProfile(const QString &name)
{
    const QVariantMap data = m_settings.value("profiles/" + name).toMap();
    m_settings.remove("profiles/" + name);
    if (m_activeProfile == name) {
        m_activeProfile.clear();
        emit activeProfileChanged();
    }
    emit profilesChanged();
    m_undo.clear();
    m_undoProfile = name;
    m_undoProfileData = data;
    emit undoAvailable(tr("Deleted profile “%1”").arg(name));
}

bool Controller::exportProfiles(const QUrl &file)
{
    QJsonObject root;
    for (const auto &name : profiles())
        root.insert(name, QJsonObject::fromVariantMap(m_settings.value("profiles/" + name).toMap()));
    QFile f(file.toLocalFile());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        emit errorOccurred(tr("Couldn't write %1").arg(f.fileName()));
        return false;
    }
    f.write(QJsonDocument(QJsonObject{{"gimbotProfiles", 1}, {"profiles", root}}).toJson());
    emit notice(tr("Exported %n profile(s)", nullptr, root.size()));
    return true;
}

int Controller::importProfiles(const QUrl &file)
{
    QFile f(file.toLocalFile());
    if (!f.open(QIODevice::ReadOnly)) {
        emit errorOccurred(tr("Couldn't read %1").arg(f.fileName()));
        return 0;
    }
    const auto doc = QJsonDocument::fromJson(f.readAll());
    const auto root = doc.object().value("profiles").toObject();
    if (root.isEmpty()) {
        emit errorOccurred(tr("That file doesn't contain any Gimbot profiles."));
        return 0;
    }
    int n = 0;
    for (auto it = root.begin(); it != root.end(); ++it) {
        QVariantMap snap;
        const auto obj = it.value().toObject().toVariantMap();
        for (const auto &k : kProfileKeys)
            if (obj.contains(k)) snap[k] = obj.value(k); // ignore anything unknown
        if (snap.isEmpty()) continue;
        m_settings.setValue("profiles/" + it.key(), snap);
        ++n;
    }
    emit profilesChanged();
    emit notice(tr("Imported %n profile(s)", nullptr, n));
    return n;
}

QStringList Controller::shutterLabels() const
{
    QStringList out;
    for (int v = t2::shutter::First; v <= t2::shutter::Last; ++v) out << QString::fromLatin1(t2::shutter::label(v));
    return out;
}
