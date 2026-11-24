#include "commands.hpp"

#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <utility>

namespace t2 {

const char *commandHelp()
{
    return "Camera\n"
           "  status                       Show camera status\n"
           "  sleep | wake                 Put the camera to sleep or wake it\n"
           "  sleep-timer SECONDS          Sleep when idle (0 = never)\n"
           "\n"
           "Tracking\n"
           "  track MODE [FRAMING]         MODE: off person group hand desk whiteboard\n"
           "                               FRAMING (person): full upper close\n"
           "  style standard|headroom|motion\n"
           "  autozoom on|off\n"
           "  gesture select|zoom|dynamic|reverse on|off\n"
           "  area on|off                  Limit tracking to an area\n"
           "  area set YAWMIN YAWMAX PITCHMIN PITCHMAX\n"
           "  area reset\n"
           "\n"
           "Gimbal and zoom\n"
           "  center                       Recenter the gimbal\n"
           "  aim PITCH YAW                Move to absolute angles (degrees)\n"
           "  turn DPITCH DYAW             Move relative to where it is\n"
           "  zoom PERCENT                 0..100\n"
           "  zoom-speed 0..10             0 = camera default\n"
           "\n"
           "Presets\n"
           "  preset list | go ID | save ID NAME | rename ID NAME | delete ID\n"
           "\n"
           "Image\n"
           "  fov wide|medium|narrow\n"
           "  hdr on|off\n"
           "  mirror on|off\n"
           "  focus auto|face|0..100\n"
           "  exposure auto|1/60|1/120|...\n"
           "  face-exposure on|off\n"
           "  wb auto|daylight|cloudy|tungsten|fluorescent|KELVIN\n"
           "  brightness|contrast|saturation|sharpness|hue VALUE\n"
           "  flicker off|50|60|auto\n"
           "\n"
           "Startup, audio and device\n"
           "  startup use-current|go|reset\n"
           "  startup-mode MODE [FRAMING]\n"
           "  mic-in-sleep on|off\n"
           "  autogain on|off\n"
           "  voice on|off                 All voice commands\n"
           "  voice language english|chinese\n"
           "  factory-reset --yes          Erase all camera settings\n";
}

namespace {

bool onOff(const std::string &s, bool &out)
{
    if (s == "on" || s == "1" || s == "true" || s == "yes") { out = true; return true; }
    if (s == "off" || s == "0" || s == "false" || s == "no") { out = false; return true; }
    return false;
}

bool parseMode(const std::string &s, Mode &m)
{
    static const std::pair<const char *, Mode> modes[] = {
        {"off", Mode::Off},   {"person", Mode::Person}, {"group", Mode::Group},
        {"hand", Mode::Hand}, {"desk", Mode::Desk},     {"whiteboard", Mode::Whiteboard}};
    for (auto &x : modes)
        if (s == x.first) { m = x.second; return true; }
    return false;
}

Framing parseFraming(const std::string &s)
{
    if (s == "full") return Framing::FullBody;
    if (s == "close") return Framing::CloseUp;
    return Framing::UpperBody;
}

std::string fmt(const char *f, ...) __attribute__((format(printf, 1, 2)));
std::string fmt(const char *f, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, f);
    vsnprintf(buf, sizeof buf, f, ap);
    va_end(ap);
    return buf;
}

} // namespace

int runCommand(Camera &cam, const std::vector<std::string> &args, std::string &out)
{
    auto arg = [&](size_t i) -> std::string { return i < args.size() ? args[i] : std::string(); };
    auto num = [&](size_t i) { return std::atoi(arg(i).c_str()); };
    auto fnum = [&](size_t i) { return std::strtof(arg(i).c_str(), nullptr); };
    auto done = [&](bool r) {
        if (!r) out += "the camera rejected the command\n";
        return r ? 0 : 1;
    };
    auto usage = [&]() {
        out += "unknown or incomplete command; see --help\n";
        return 2;
    };
    if (args.empty()) return usage();
    const std::string cmd = args[0];
    bool flag = false;

    if (cmd == "status") {
        const Status s = cam.status();
        static const char *fovs[] = {"wide (86°)", "medium (78°)", "narrow (65°)"};
        static const char *framings[] = {"full body", "upper body", "close-up"};
        out += fmt("Model:     %s\nSerial:    %s\nFirmware:  %s\n", cam.model().c_str(), cam.serial().c_str(),
                   cam.firmware().c_str());
        out += fmt("State:     %s\n", s.asleep ? "asleep" : "awake");
        out += fmt("Tracking:  %s", modeName(s.mode));
        if (s.mode == Mode::Person && s.framing >= 0 && s.framing < 3) out += fmt(" (%s)", framings[s.framing]);
        out += fmt("\nZoom:      %d%%\n", s.zoomPercent);
        GimbalPos pos;
        if (cam.position(pos)) out += fmt("Gimbal:    pitch %.1f°, yaw %.1f°\n", pos.pitch, pos.yaw);
        out += fmt("FOV:       %s\n", s.fov >= 0 && s.fov < 3 ? fovs[s.fov] : "?");
        out += fmt("HDR:       %s\nMirror:    %s\n", s.hdr ? "on" : "off", s.mirrored ? "on" : "off");
        if (s.autoFocus) out += fmt("Focus:     auto%s\n", s.faceFocus ? " (face)" : "");
        else out += fmt("Focus:     manual %d\n", s.manualFocus);
        return 0;
    }
    if (cmd == "sleep") return done(cam.setAsleep(true));
    if (cmd == "wake") return done(cam.setAsleep(false));
    if (cmd == "sleep-timer" && args.size() > 1) return done(cam.setSleepTimer(num(1)));

    Mode mode;
    if (cmd == "track" && parseMode(arg(1), mode)) return done(cam.setMode(mode, parseFraming(arg(2))));
    if (cmd == "startup-mode" && parseMode(arg(1), mode)) return done(cam.setBootMode(mode, parseFraming(arg(2))));
    if (cmd == "style") {
        if (arg(1) == "standard") return done(cam.setTrackStyle(TrackStyle::Standard));
        if (arg(1) == "headroom") return done(cam.setTrackStyle(TrackStyle::Headroom));
        if (arg(1) == "motion") return done(cam.setTrackStyle(TrackStyle::Motion));
    }
    if (cmd == "autozoom" && onOff(arg(1), flag)) return done(cam.setAutoZoom(flag));
    if (cmd == "gesture" && onOff(arg(2), flag)) {
        if (arg(1) == "select") return done(cam.setGesture(0, flag));
        if (arg(1) == "zoom") return done(cam.setGesture(1, flag));
        if (arg(1) == "dynamic") return done(cam.setGesture(2, flag));
        if (arg(1) == "reverse") return done(cam.setGesture(3, flag));
    }
    if (cmd == "area") {
        if (onOff(arg(1), flag)) return done(cam.setZoneEnabled(flag));
        if (arg(1) == "reset") return done(cam.resetZone());
        if (arg(1) == "set" && args.size() > 5) return done(cam.setZone({fnum(2), fnum(3), fnum(4), fnum(5)}));
    }

    if (cmd == "center") return done(cam.recenter());
    if (cmd == "aim" && args.size() > 2) return done(cam.moveTo(fnum(1), fnum(2)));
    if (cmd == "turn" && args.size() > 2) {
        GimbalPos p;
        if (!cam.position(p)) {
            out += "could not read the gimbal position\n";
            return 1;
        }
        return done(cam.moveTo(p.pitch + fnum(1), p.yaw + fnum(2)));
    }
    if (cmd == "zoom" && args.size() > 1) return done(cam.setZoom(num(1)));
    if (cmd == "zoom-speed" && args.size() > 1) return done(cam.setZoomSpeed(num(1)));

    if (cmd == "preset") {
        if (arg(1) == "list" || arg(1).empty()) {
            auto list = cam.presets();
            if (list.empty()) out += "No presets saved.\n";
            for (auto &p : list)
                out += fmt("%d  %-20s pitch %.1f°  yaw %.1f°  zoom %.2f\n", p.id, p.name.c_str(), p.pitch, p.yaw,
                           p.zoom);
            return 0;
        }
        if (args.size() < 3) return usage();
        const int id = num(2);
        if (arg(1) == "go") return done(cam.goToPreset(id));
        if (arg(1) == "delete") return done(cam.deletePreset(id));
        if (arg(1) == "save") return done(cam.savePreset(id, args.size() > 3 ? arg(3) : "Preset " + arg(2)));
        if (arg(1) == "rename" && args.size() > 3) return done(cam.renamePreset(id, arg(3)));
    }

    if (cmd == "fov") {
        if (arg(1) == "wide") return done(cam.setFov(Fov::Wide86));
        if (arg(1) == "medium") return done(cam.setFov(Fov::Medium78));
        if (arg(1) == "narrow") return done(cam.setFov(Fov::Narrow65));
    }
    if (cmd == "hdr" && onOff(arg(1), flag)) return done(cam.setHdr(flag));
    if (cmd == "mirror" && onOff(arg(1), flag)) return done(cam.setMirror(flag));
    if (cmd == "face-exposure" && onOff(arg(1), flag)) return done(cam.setFaceExposure(flag));
    if (cmd == "focus") {
        if (arg(1) == "auto") return done(cam.setAutoFocus(true) && cam.setFaceFocus(false));
        if (arg(1) == "face") return done(cam.setAutoFocus(true) && cam.setFaceFocus(true));
        if (!arg(1).empty()) return done(cam.setManualFocus(num(1)));
    }
    if (cmd == "exposure") {
        if (arg(1) == "auto") return done(cam.setExposure(true, 30));
        for (int v = shutter::First; v <= shutter::Last; ++v)
            if (arg(1) == shutter::label(v)) return done(cam.setExposure(false, v));
    }
    if (cmd == "wb") {
        if (arg(1) == "auto") return done(cam.setWhiteBalance(wb::Auto, 0));
        if (arg(1) == "daylight") return done(cam.setWhiteBalance(wb::Daylight, 0));
        if (arg(1) == "cloudy") return done(cam.setWhiteBalance(wb::Cloudy, 0));
        if (arg(1) == "tungsten") return done(cam.setWhiteBalance(wb::Tungsten, 0));
        if (arg(1) == "fluorescent") return done(cam.setWhiteBalance(wb::Fluorescent, 0));
        if (num(1) > 0) return done(cam.setWhiteBalance(wb::Manual, num(1)));
    }
    if (args.size() > 1) {
        static const std::pair<const char *, ImageParam> params[] = {{"brightness", ImageParam::Brightness},
                                                                     {"contrast", ImageParam::Contrast},
                                                                     {"saturation", ImageParam::Saturation},
                                                                     {"sharpness", ImageParam::Sharpness},
                                                                     {"hue", ImageParam::Hue}};
        for (auto &p : params)
            if (cmd == p.first) return done(cam.setImage(p.second, num(1)));
    }
    if (cmd == "flicker") {
        if (arg(1) == "off") return done(cam.setAntiFlicker(0));
        if (arg(1) == "50") return done(cam.setAntiFlicker(1));
        if (arg(1) == "60") return done(cam.setAntiFlicker(2));
        if (arg(1) == "auto") return done(cam.setAntiFlicker(3));
    }

    if (cmd == "startup") {
        if (arg(1) == "use-current") return done(cam.bootUseCurrent());
        if (arg(1) == "go") return done(cam.bootGo());
        if (arg(1) == "reset") return done(cam.bootReset());
    }
    if (cmd == "mic-in-sleep" && onOff(arg(1), flag)) return done(cam.setMicDuringSleep(flag));
    if (cmd == "autogain" && onOff(arg(1), flag)) return done(cam.setAudioAutoGain(flag));
    if (cmd == "voice") {
        if (onOff(arg(1), flag)) {
            bool r = true;
            for (int v = 0; v < static_cast<int>(Voice::Count); ++v)
                r = cam.setVoiceCommand(static_cast<Voice>(v), flag) && r;
            return done(r);
        }
        if (arg(1) == "language" && arg(2) == "english") return done(cam.setVoiceLanguage(VoiceLanguage::English));
        if (arg(1) == "language" && arg(2) == "chinese") return done(cam.setVoiceLanguage(VoiceLanguage::Chinese));
    }
    if (cmd == "factory-reset") {
        if (arg(1) != "--yes") {
            out += "this erases presets and all camera settings; run 'factory-reset --yes' to confirm\n";
            return 2;
        }
        return done(cam.factoryReset());
    }
    return usage();
}

} // namespace t2
