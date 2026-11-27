// SPDX-License-Identifier: MIT
// Gimbot: an unofficial Linux control app for OBSBOT cameras.
#include "controller.hpp"
#include "crashlog.hpp"
#include "logger.hpp"
#include "selftest.hpp"
#include "platform.hpp"
#include "updater.hpp"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSocketNotifier>
#include <QTimer>

#include <csignal>
#include <cstdio>
#include <vector>
#include <sys/socket.h>
#include <unistd.h>

#ifdef GIMBOT_HAVE_KF6
#include <KAboutData>
#include <KCrash>
#endif

#ifndef GIMBOT_VERSION
#define GIMBOT_VERSION "0.0.0"
#endif
#ifndef GIMBOT_REPO
#define GIMBOT_REPO ""
#endif

static const char kService[] = "io.github.Matt_B_007.Gimbot";

// Ctrl+C in a terminal, or a normal "please quit" from the system, should
// close Gimbot properly so the next start doesn't think it crashed. Signal
// handlers can't call Qt, so they write a byte that Qt picks up.
static int quitPipe[2] = {-1, -1};
static void onQuitSignal(int)
{
    const char c = 1;
    [[maybe_unused]] auto n = ::write(quitPipe[1], &c, 1);
}
static void quitOnSignals(QCoreApplication &app)
{
    if (::socketpair(AF_UNIX, SOCK_STREAM, 0, quitPipe) != 0) return;
    auto *notifier = new QSocketNotifier(quitPipe[0], QSocketNotifier::Read, &app);
    QObject::connect(notifier, &QSocketNotifier::activated, &app, [&app] {
        char c;
        [[maybe_unused]] auto n = ::read(quitPipe[0], &c, 1);
        qInfo() << "Asked to quit";
        app.quit();
    });
    struct sigaction sa = {};
    sa.sa_handler = onQuitSignal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    for (int sig : {SIGINT, SIGTERM, SIGHUP}) sigaction(sig, &sa, nullptr);
}

int main(int argc, char *argv[])
{
    // gimbot --self-test [--quick]: off-screen, temporary folders, then exit.
    if (selftest::requested(argc, argv)) return selftest::run(argc, argv);

    // Terminal-only options (help, version, report, update, rollback,
    // uninstall) also work without a desktop, e.g. over SSH.
    if (qEnvironmentVariableIsEmpty("DISPLAY") && qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")) {
        for (int i = 1; i < argc; ++i) {
            const QByteArray a(argv[i]);
            if (a == "-h" || a == "--help" || a == "-v" || a == "--version" || a == "--report" || a == "--update"
                || a == "--rollback" || a == "--uninstall") {
                qputenv("QT_QPA_PLATFORM", "offscreen");
                break;
            }
        }
    }

    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("gimbot"));
    QApplication::setApplicationName(QStringLiteral("gimbot"));
    QApplication::setApplicationDisplayName(QStringLiteral("Gimbot"));
    QApplication::setApplicationVersion(QStringLiteral(GIMBOT_VERSION));
    QApplication::setDesktopFileName(QStringLiteral("io.github.Matt_B_007.Gimbot"));
    QApplication::setWindowIcon(QIcon::fromTheme("gimbot", QIcon(":/qt/qml/Gimbot/icons/gimbot.svg")));
    QApplication::setQuitOnLastWindowClosed(false); // keep running in the tray

#ifdef GIMBOT_HAVE_KF6
    KAboutData about(QStringLiteral("gimbot"), QStringLiteral("Gimbot"), QStringLiteral(GIMBOT_VERSION),
                     QStringLiteral("Control OBSBOT cameras on Linux. Not affiliated with OBSBOT or Remo Tech."),
                     KAboutLicense::MIT);
    if (qstrlen(GIMBOT_REPO) > 0) {
        about.setHomepage(QStringLiteral("https://github.com/" GIMBOT_REPO));
        about.setBugAddress(QByteArray("https://github.com/" GIMBOT_REPO "/issues"));
    }
    // Without this KAboutData invents "org.kde.gimbot", which matches no
    // .desktop file, so the desktop portal can't identify the app.
    about.setDesktopFileName(QStringLiteral("io.github.Matt_B_007.Gimbot"));
    KAboutData::setApplicationData(about);
    QApplication::setDesktopFileName(QStringLiteral("io.github.Matt_B_007.Gimbot"));
    KCrash::initialize();
#endif

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Control OBSBOT cameras."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption hidden("hidden", "Start in the tray without opening the window.");
    QCommandLineOption fake("fake", "Use a simulated camera (also GIMBOT_FAKE_CAMERA=1).");
    QCommandLineOption shots("screenshots", "Save screenshots of each screen to DIR and quit (for testing).", "DIR");
    QCommandLineOption selfTest("self-test", "Check that Gimbot works, then exit (add --quick for the short check).");
    QCommandLineOption quick("quick", "With --self-test: only start, load the interface and read settings.");
    QCommandLineOption report("report", "Save a problem report (personal details hidden) to Downloads, print where, and exit.");
    QCommandLineOption update("update", "Install the newest version for your update channel (runs gimbot-update).");
    QCommandLineOption rollback("rollback", "Go back to the version installed before the last update.");
    QCommandLineOption uninstall("uninstall", "Remove Gimbot (asks whether to delete your settings too).");
    parser.addOptions({hidden, fake, shots, selfTest, quick, report, update, rollback, uninstall});
    parser.process(app);

    // --update, --rollback and --uninstall hand over to the installer, which
    // shows its progress here in the terminal.
    if (parser.isSet(update) || parser.isSet(rollback) || parser.isSet(uninstall)) {
        QString installType = QStringLiteral("manual");
        QFile typeFile(QStringLiteral(GIMBOT_LIBDIR "/gimbot/install-type"));
        if (typeFile.open(QIODevice::ReadOnly)) installType = QString::fromUtf8(typeFile.readAll()).trimmed();
        const bool beta = QStringLiteral(GIMBOT_VERSION).contains('-');
        if (installType == QLatin1String("aur")) {
            const QString pkg = beta ? QStringLiteral("gimbot-beta") : QStringLiteral("gimbot");
            if (parser.isSet(update)) std::printf("Gimbot came from the AUR, so update it there:\n  paru -Syu %s\n", qPrintable(pkg));
            else if (parser.isSet(rollback)) std::printf("Gimbot came from the AUR. To go back, reinstall the older package from your package cache:\n  sudo pacman -U /var/cache/pacman/pkg/%s-<version>-*.pkg.tar.zst\n", qPrintable(pkg));
            else std::printf("Gimbot came from the AUR. Remove it with:\n  sudo pacman -R %s\n", qPrintable(pkg));
            return 0;
        }
        const QString helper = QStandardPaths::findExecutable(QStringLiteral("gimbot-update"));
        if (helper.isEmpty()) {
            std::fprintf(stderr, "gimbot-update isn't installed, so Gimbot can't do this itself. Use the install line from the README instead.\n");
            return 1;
        }
        QStringList args;
        if (parser.isSet(rollback)) args << QStringLiteral("--rollback");
        if (parser.isSet(uninstall)) args << QStringLiteral("--uninstall");
        std::vector<QByteArray> store{QFile::encodeName(helper)};
        for (const QString &a : args) store.push_back(a.toUtf8());
        std::vector<char *> argvOut;
        for (auto &b : store) argvOut.push_back(b.data());
        argvOut.push_back(nullptr);
        std::fflush(stdout);
        execv(argvOut[0], argvOut.data());
        std::fprintf(stderr, "Couldn't start %s\n", qPrintable(helper));
        return 1;
    }
    const bool screenshotMode = parser.isSet(shots);
    if (screenshotMode) // keep test runs from touching the user's real settings
        QApplication::setOrganizationName(QStringLiteral("gimbot-screenshots"));

    // --report while Gimbot is running: ask the running copy, which knows the camera.
    auto bus = QDBusConnection::sessionBus();
    const bool running = bus.isConnected() && bus.interface()->isServiceRegistered(kService);
    if (parser.isSet(report) && running) {
        const QDBusMessage reply = bus.call(
            QDBusMessage::createMethodCall(kService, "/Gimbot", "io.github.Matt_B_007.Gimbot1", "SaveReport"));
        const QString path = reply.arguments().value(0).toString();
        if (reply.type() != QDBusMessage::ReplyMessage || path.isEmpty()) {
            std::fprintf(stderr, "Couldn't save the report.\n");
            return 1;
        }
        std::printf("Report saved to %s\nAttach it to an issue at https://github.com/%s/issues\n", qPrintable(path), GIMBOT_REPO);
        return 0;
    }

    // One instance at a time: if Gimbot is already running, bring it forward.
    if (!screenshotMode && running) {
        bus.call(QDBusMessage::createMethodCall(kService, "/Gimbot", "io.github.Matt_B_007.Gimbot1", "Activate"));
        return 0;
    }

    Logger::install();
    qInfo() << "Gimbot" << GIMBOT_VERSION << "starting, Qt" << qVersion();
    if (!screenshotMode) CrashLog::install();

    // Use our own fully styled controls everywhere, so the app looks the
    // same in every theme; colors still follow the system palette.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool simulated = parser.isSet(fake) || qEnvironmentVariableIsSet("GIMBOT_FAKE_CAMERA");
    Controller cam(simulated);
    Updater updater(QStringLiteral(GIMBOT_REPO), QStringLiteral(GIMBOT_VERSION));
    Platform platform(&cam, &updater, QStringLiteral(GIMBOT_REPO));
    DBusService dbus(&cam, &platform);

    if (parser.isSet(report)) { // no running copy: report from the log file
        platform.setReportFromFile(true);
        const QString path = platform.saveReport(QString(), QString(), false);
        if (path.isEmpty()) {
            std::fprintf(stderr, "Couldn't save the report.\n");
            return 1;
        }
        std::printf("Report saved to %s\nAttach it to an issue at https://github.com/%s/issues\n", qPrintable(path), GIMBOT_REPO);
        return 0;
    }

    if (!screenshotMode) {
        platform.markRunning();
        if (bus.isConnected()) {
            bus.registerObject("/Gimbot", &dbus, QDBusConnection::ExportScriptableSlots);
            bus.registerService(kService);
        }
        platform.setupTray();
        platform.setupShortcuts();
    }

    auto applyAppSetting = [&](const QString &key, const QVariant &v) {
        if (key == "verboseLogging") {
            Logger::setVerbose(v.toBool());
            t2::Discovery::setVerbose(v.toBool());
        } else if (key == "updateChannel") {
            updater.setChannel(v.toInt());
        } else if (key == "autostart") {
            platform.applyAutostart(v.toBool());
        }
    };
    QObject::connect(&cam, &Controller::appSettingChanged, &app, applyAppSetting);
    for (const char *k : {"verboseLogging", "updateChannel"}) applyAppSetting(k, cam.get(k));
    if (simulated) { // pretend an update is out, to try the update screens
        updater.setSimulated(true);
        QTimer::singleShot(screenshotMode ? 500 : 3000, &updater, &Updater::check);
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("cam", &cam);
    engine.rootContext()->setContextProperty("platform", &platform);
    engine.rootContext()->setContextProperty("updater", &updater);
    engine.rootContext()->setContextProperty("startHidden", parser.isSet(hidden));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    engine.loadFromModule("Gimbot", "Main");
#else
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Gimbot/Main.qml")));
#endif
    if (engine.rootObjects().isEmpty()) return 1;

    QObject::connect(&platform, &Platform::quitRequested, &app, &QCoreApplication::quit);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &platform, &Platform::markCleanExit);
    quitOnSignals(app);

    // A newer OBSBOT SDK in Downloads? Look shortly after starting, then now and then.
    if (!screenshotMode) {
        QTimer::singleShot(3000, &platform, &Platform::checkForNewSdk);
        auto *sdkTimer = new QTimer(&app);
        QObject::connect(sdkTimer, &QTimer::timeout, &platform, &Platform::checkForNewSdk);
        sdkTimer->start(10 * 60 * 1000);
    }

    if (screenshotMode) {
        // Visit each screen and save a picture of it. Used to check the
        // interface without a display or a camera.
        const QString dir = parser.value(shots);
        QDir().mkpath(dir);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        engine.rootObjects().first()->setProperty("screenshotMode", true);
        const QStringList steps = {"readme-dark", "readme-light", "studio",  "more", "settings", "settings:image", "settings:motion", "settings:app",
                                   "settings:device", "palette", "report", "report-github", "about", "connect", "tour",
                                   "directions", "uninstall", "shortcuts", "studio-dark", "settings:voice-dark",
                                   "settings:area-dark", "report-dark", "connect-dark", "update", "updating",
                                   "updated", "update-error", "small", "small-dark",
                                   "studio-light", "settings-light", "report-light", "connect-light", "update-light"};
        auto index = std::make_shared<int>(0);
        auto *timer = new QTimer(&app);
        timer->setInterval(1400);
        QObject::connect(timer, &QTimer::timeout, &app, [=] {
            if (*index > 0) {
                const QString name = steps[*index - 1].section(':', 0, 0) +
                                     (steps[*index - 1].contains(':') ? "-" + steps[*index - 1].section(':', 1) : "");
                window->grabWindow().save(dir + "/" + name + ".png");
            }
            if (*index >= steps.size()) {
                QCoreApplication::quit();
                return;
            }
            QMetaObject::invokeMethod(window, "showScreen", Q_ARG(QVariant, steps[*index]));
            ++*index;
        });
        QTimer::singleShot(2500, timer, [timer] { timer->start(); });
    }

    cam.start();
    return app.exec();
}
