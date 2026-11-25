// Gimbot: an unofficial Linux control app for OBSBOT cameras.
#include "controller.hpp"
#include "logger.hpp"
#include "platform.hpp"
#include "updater.hpp"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSocketNotifier>
#include <QTimer>

#include <csignal>
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
    KAboutData::setApplicationData(about);
    KCrash::initialize();
#endif

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Control OBSBOT cameras."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption hidden("hidden", "Start in the tray without opening the window.");
    QCommandLineOption fake("fake", "Use a simulated camera (also GIMBOT_FAKE_CAMERA=1).");
    QCommandLineOption shots("screenshots", "Save screenshots of each screen to DIR and quit (for testing).", "DIR");
    parser.addOptions({hidden, fake, shots});
    parser.process(app);
    const bool screenshotMode = parser.isSet(shots);
    if (screenshotMode) // keep test runs from touching the user's real settings
        QApplication::setOrganizationName(QStringLiteral("gimbot-screenshots"));

    // One instance at a time: if Gimbot is already running, bring it forward.
    auto bus = QDBusConnection::sessionBus();
    if (!screenshotMode && bus.isConnected() && bus.interface()->isServiceRegistered(kService)) {
        bus.call(QDBusMessage::createMethodCall(kService, "/Gimbot", "io.github.Matt_B_007.Gimbot1", "Activate"));
        return 0;
    }

    Logger::install();
    qInfo() << "Gimbot" << GIMBOT_VERSION << "starting, Qt" << qVersion();

    // Use our own fully styled controls everywhere, so the app looks the
    // same in every theme; colors still follow the system palette.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool simulated = parser.isSet(fake) || qEnvironmentVariableIsSet("GIMBOT_FAKE_CAMERA");
    Controller cam(simulated);
    Updater updater(QStringLiteral(GIMBOT_REPO), QStringLiteral(GIMBOT_VERSION));
    Platform platform(&cam, &updater, QStringLiteral(GIMBOT_REPO));
    DBusService dbus(&cam, &platform);

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
        const QStringList steps = {"studio",  "more", "settings", "settings:image", "settings:motion", "settings:app",
                                   "settings:device", "palette", "report", "about", "connect", "tour",
                                   "directions", "uninstall", "studio-dark", "settings:voice-dark",
                                   "settings:area-dark", "report-dark", "connect-dark", "update", "updating",
                                   "updated", "update-error", "small", "small-dark"};
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
