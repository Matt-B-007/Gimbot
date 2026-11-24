// gimbotctl: command-line control for OBSBOT Tiny 2 cameras (part of Gimbot).
//
// If the Gimbot app is running, commands go through it over D-Bus, because
// only one program can control the camera at a time. Otherwise gimbotctl
// opens the camera itself.
#include "camera.hpp"
#include "commands.hpp"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QStringList>

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

using namespace std::chrono_literals;

static const char kService[] = "io.github.Matt_B_007.Gimbot";

static void usage()
{
    std::printf("Usage: gimbotctl [--serial SN] [--direct] [--fake] COMMAND [ARGS]\n\n"
                "  list                         List connected Tiny 2 cameras\n\n%s\n"
                "Options:\n"
                "  --serial SN   Use the camera with this serial number\n"
                "  --direct      Talk to the camera even if the Gimbot app is running\n"
                "  --fake        Use a simulated camera (for testing)\n",
                t2::commandHelp());
}

static int fail(const char *what)
{
    std::fprintf(stderr, "gimbotctl: %s\n", what);
    return 1;
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    std::vector<std::string> args(argv + 1, argv + argc);
    std::string serial;
    bool direct = false, fake = false;
    while (!args.empty() && args[0].rfind("--", 0) == 0 && args[0] != "--help") {
        if (args[0] == "--serial" && args.size() > 1) {
            serial = args[1];
            args.erase(args.begin(), args.begin() + 2);
        } else if (args[0] == "--direct") {
            direct = true;
            args.erase(args.begin());
        } else if (args[0] == "--fake") {
            fake = true;
            args.erase(args.begin());
        } else {
            break;
        }
    }
    if (args.empty() || args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
        usage();
        return args.empty() ? 2 : 0;
    }

    // Hand the command to the running app if there is one.
    if (!direct && !fake && args[0] != "list") {
        auto bus = QDBusConnection::sessionBus();
        if (bus.isConnected() && bus.interface()->isServiceRegistered(kService)) {
            QStringList list;
            for (auto &a : args) list << QString::fromStdString(a);
            auto msg = QDBusMessage::createMethodCall(kService, "/Gimbot", "io.github.Matt_B_007.Gimbot1", "Run");
            msg << list;
            auto reply = bus.call(msg, QDBus::Block, 15000);
            if (reply.type() == QDBusMessage::ReplyMessage && reply.arguments().size() == 2) {
                const QString text = reply.arguments().at(1).toString();
                std::fputs(text.toLocal8Bit().constData(), reply.arguments().at(0).toInt() == 0 ? stdout : stderr);
                return reply.arguments().at(0).toInt();
            }
            std::fprintf(stderr, "gimbotctl: the Gimbot app did not answer (%s); trying the camera directly\n",
                         reply.errorMessage().toLocal8Bit().constData());
        }
    }

    std::unique_ptr<t2::Camera> cam;
    if (fake) {
        cam = t2::openFakeCamera();
    } else {
        if (!t2::Discovery::start(nullptr))
            return fail("/sys/bus/usb/devices is missing, so cameras cannot be detected");
        // The SDK scans in the background; give it up to 3 s to find a camera.
        for (int i = 0; i < 30 && t2::Discovery::cameras().empty(); ++i) std::this_thread::sleep_for(100ms);
        if (args[0] == "list") {
            auto list = t2::Discovery::cameras();
            if (list.empty()) return fail("no Tiny 2 found");
            for (auto &sn : list) {
                auto c = t2::openSdkCamera(sn);
                std::printf("%s  %s  firmware %s\n", sn.c_str(), c ? c->model().c_str() : "?",
                            c ? c->firmware().c_str() : "?");
            }
            return 0;
        }
        cam = t2::openSdkCamera(serial);
        if (!cam) return fail("no Tiny 2 found (is it plugged in, and is the udev rule installed?)");
    }

    std::string out;
    const int code = t2::runCommand(*cam, args, out);
    std::fputs(out.c_str(), code == 0 ? stdout : stderr);
    return code;
}
