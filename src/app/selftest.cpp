// SPDX-License-Identifier: MIT
#include "selftest.hpp"

#include "commands.hpp"
#include "controller.hpp"
#include "crashlog.hpp"
#include "logger.hpp"
#include "platform.hpp"
#include "settingsstore.hpp"
#include "updater.hpp"

#include <QApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QTemporaryDir>
#include <QTimer>

#include <cstdio>
#include <cstring>
#include <link.h>

namespace selftest {

namespace {

int g_failed = 0, g_passed = 0;
QStringList g_qmlProblems;

void report(bool ok, const char *name, const QString &detail = {})
{
    ok ? ++g_passed : ++g_failed;
    std::printf("%s  %s%s\n", ok ? "ok  " : "FAIL", name,
                detail.isEmpty() ? "" : qPrintable(QStringLiteral(" (%1)").arg(detail)));
    std::fflush(stdout);
}

void collect(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    // Anything wrong in the interface shows up as a warning from QML.
    if (type != QtDebugMsg && type != QtInfoMsg &&
        (msg.contains("qrc:") || msg.contains("TypeError") || msg.contains("ReferenceError") ||
         msg.contains("is not a type") || msg.contains("Binding loop")))
        g_qmlProblems << msg;
}

QString realSettingsFile()
{
    QString base = qEnvironmentVariable("XDG_CONFIG_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.config";
    return base + "/gimbot/gimbot.conf";
}

#ifdef GIMBOT_HAVE_SDK
int findLibdev(struct dl_phdr_info *info, size_t, void *data)
{
    if (info->dlpi_name && std::strstr(info->dlpi_name, "libdev.so")) {
        *static_cast<QString *>(data) = QString::fromLocal8Bit(info->dlpi_name);
        return 1;
    }
    return 0;
}
#endif

void checkInterface()
{
    qInstallMessageHandler(collect);
    Controller cam(true);
    Updater updater(QStringLiteral(GIMBOT_REPO), QStringLiteral(GIMBOT_VERSION));
    Platform platform(&cam, &updater, QStringLiteral(GIMBOT_REPO));
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("cam", &cam);
    engine.rootContext()->setContextProperty("platform", &platform);
    engine.rootContext()->setContextProperty("updater", &updater);
    engine.rootContext()->setContextProperty("startHidden", true);
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    engine.loadFromModule("Gimbot", "Main");
#else
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Gimbot/Main.qml")));
#endif
    // Let bindings, timers and the simulated camera settle.
    QElapsedTimer t;
    t.start();
    while (t.elapsed() < 1500) QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    qInstallMessageHandler(nullptr);
    const bool loaded = !engine.rootObjects().isEmpty();
    report(loaded && g_qmlProblems.isEmpty(), "Loads the interface",
           !loaded                   ? QStringLiteral("the main window didn't load")
           : g_qmlProblems.isEmpty() ? QString()
                                     : g_qmlProblems.first().left(160));
}

void checkCamera()
{
    auto cam = t2::openFakeCamera();
    std::string out;
    bool ok = t2::runCommand(*cam, {"status"}, out) == 0 && out.find("Tiny 2") != std::string::npos;
    ok = ok && t2::runCommand(*cam, {"zoom", "40"}, out) == 0 && cam->status().zoomPercent == 40;
    t2::GimbalPos p;
    ok = ok && t2::runCommand(*cam, {"aim", "10", "20"}, out) == 0 && cam->position(p);
    ok = ok && !cam->presets().empty();
    report(ok, "Simulated camera (status, zoom, aim, presets)");
}

void checkSettingsRoundTrip()
{
    // Runs in the temporary config folder set up by run().
    bool ok = true;
    {
        QSettings s;
        s.clear();
        s.setValue("settings/fov", 2);
        s.sync();
        ok = s.status() == QSettings::NoError;
    }
    QSettings s;
    ok = ok && s.value("settings/fov").toInt() == 2;
    // A version-1 file (an existing install from before versions).
    const auto r = settingsstore::migrate(s);
    ok = ok && r.from == 1 && s.value("meta/settingsVersion").toInt() == settingsstore::kCurrentVersion &&
         s.value("settings/tourDone").toBool();
    // Backups: one made, a second within 15 minutes skipped.
    const QString dir = QFileInfo(s.fileName()).absolutePath() + "/selftest-backups"; // fresh folder
    ok = ok && settingsstore::backup(s.fileName(), dir) && !settingsstore::backup(s.fileName(), dir);
    // Qt saves through a temporary file + rename: nothing left behind.
    const auto leftovers = QDir(QFileInfo(s.fileName()).absolutePath()).entryList({"*.lock", "*.tmp*"}, QDir::Files);
    ok = ok && leftovers.isEmpty();
    report(ok, "Settings: save, read back, migrate, back up");
}

void checkFolders()
{
    const bool ok = QDir().mkpath(Logger::logDir()) && QDir().mkpath(CrashLog::dir()) &&
                    QFileInfo(Logger::logDir()).isWritable() && QFileInfo(CrashLog::dir()).isWritable();
    report(ok, "Log and crash folders can be written");
}

void checkLibrary()
{
#ifdef GIMBOT_HAVE_SDK
    QString path;
    dl_iterate_phdr(findLibdev, &path);
    report(!path.isEmpty() && QFileInfo::exists(path), "OBSBOT library loaded", path.isEmpty() ? "not found" : path);
#else
    std::printf("skip  OBSBOT library (this build has no SDK, simulated camera only)\n");
#endif
}

} // namespace

bool requested(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i)
        if (std::strcmp(argv[i], "--self-test") == 0) return true;
    return false;
}

int run(int argc, char *argv[])
{
    bool quick = false;
    for (int i = 1; i < argc; ++i)
        if (std::strcmp(argv[i], "--quick") == 0) quick = true;

    // Off-screen and in temporary folders: no windows, no changes to the
    // user's settings, logs or saved data.
    const QString realSettings = realSettingsFile();
    QTemporaryDir tmp;
    if (!tmp.isValid()) {
        std::printf("FAIL  Can't create a temporary folder\n");
        return 1;
    }
    for (const char *var : {"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"}) {
        const QString d = tmp.path() + "/" + QString::fromLatin1(var).toLower();
        QDir().mkpath(d);
        qputenv(var, d.toLocal8Bit());
    }
    if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "offscreen");

    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("gimbot"));
    QApplication::setApplicationName(QStringLiteral("gimbot"));
    QApplication::setApplicationVersion(QStringLiteral(GIMBOT_VERSION));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    std::printf("Gimbot %s self-test%s\n", GIMBOT_VERSION, quick ? " (quick)" : "");
    report(true, "Starts");

    {
        // Read the real settings file (read-only).
        QSettings s(realSettings, QSettings::IniFormat);
        if (!QFileInfo::exists(realSettings))
            report(true, "Reads the settings", "none saved yet");
        else
            report(s.status() == QSettings::NoError, "Reads the settings",
                   QStringLiteral("version %1").arg(s.value("meta/settingsVersion", 1).toInt()));
    }
    checkInterface();
    if (!quick) {
        checkCamera();
        checkSettingsRoundTrip();
        checkFolders();
        checkLibrary();
    }
    std::printf(g_failed ? "Self-test FAILED: %d of %d checks\n" : "Self-test passed (%d checks)\n",
                g_failed ? g_failed : g_passed, g_passed + g_failed);
    return g_failed ? 1 : 0;
}

} // namespace selftest
