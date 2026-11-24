#include "platform.hpp"

#include "controller.hpp"
#include "logger.hpp"
#include "updater.hpp"

#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QClipboard>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QMenu>
#include <QStandardPaths>
#include <QSysInfo>
#include <QSystemTrayIcon>
#include <QUrl>
#include <QUrlQuery>

#ifdef GIMBOT_HAVE_KF6
#include <KGlobalAccel>
#include <KStatusNotifierItem>
#endif

#ifndef GIMBOT_VERSION
#define GIMBOT_VERSION "0.0.0"
#endif
#ifndef GIMBOT_SDK_VERSION
#define GIMBOT_SDK_VERSION "unknown"
#endif

namespace {
QString markerPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/running.lock";
}
} // namespace

Platform::Platform(Controller *cam, Updater *updater, const QString &repo, QObject *parent)
    : QObject(parent), m_cam(cam), m_updater(updater), m_repo(repo)
{
}

Platform::~Platform()
{
    if (!m_menuOwnedByTray) delete m_menu;
}

QString Platform::version() const { return QStringLiteral(GIMBOT_VERSION); }
QString Platform::sdkVersion() const { return QStringLiteral(GIMBOT_SDK_VERSION); }
QString Platform::qtVersion() const { return QString::fromLatin1(qVersion()); }
QString Platform::system() const
{
    return QStringLiteral("%1, kernel %2, %3 (%4)")
        .arg(QSysInfo::prettyProductName(), QSysInfo::kernelVersion(),
             qEnvironmentVariable("XDG_CURRENT_DESKTOP", "unknown desktop"),
             qEnvironmentVariable("XDG_SESSION_TYPE", "unknown session"));
}
bool Platform::kdeIntegration() const
{
#ifdef GIMBOT_HAVE_KF6
    return true;
#else
    return false;
#endif
}
QString Platform::repoUrl() const { return m_repo.isEmpty() ? QString() : "https://github.com/" + m_repo; }
QString Platform::logFile() const { return Logger::logFile(); }

// ---------------------------------------------------------------- crash detection

void Platform::markRunning()
{
    QDir().mkpath(QFileInfo(markerPath()).path());
    m_crashed = QFile::exists(markerPath());
    if (m_crashed) qWarning() << "The previous session did not exit cleanly";
    QFile f(markerPath());
    if (f.open(QIODevice::WriteOnly)) f.write(QByteArray::number(QCoreApplication::applicationPid()));
}

void Platform::markCleanExit() { QFile::remove(markerPath()); }

void Platform::dismissCrash()
{
    m_crashed = false;
    emit crashChanged();
}

// ---------------------------------------------------------------- autostart

void Platform::applyAutostart(bool on)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/autostart";
    const QString path = dir + "/io.github.Matt_B_007.Gimbot.desktop";
    if (!on) {
        QFile::remove(path);
        return;
    }
    QDir().mkpath(dir);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Couldn't write" << path;
        return;
    }
    // Packaged installs live in /usr/bin; a development build runs from its own path.
    const QString exe = QCoreApplication::applicationFilePath().startsWith("/usr/")
                            ? QStringLiteral("gimbot")
                            : QCoreApplication::applicationFilePath();
    f.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=Gimbot\nExec=%1 --hidden\nIcon=gimbot\n"
                           "X-GNOME-Autostart-enabled=true\nX-KDE-autostart-phase=2\n")
                .arg(exe)
                .toUtf8());
}

// ---------------------------------------------------------------- tray

void Platform::setupTray()
{
    m_menu = new QMenu;
    connect(m_menu, &QMenu::aboutToShow, this, &Platform::rebuildMenu);
    rebuildMenu();
#ifdef GIMBOT_HAVE_KF6
    auto *sni = new KStatusNotifierItem(QStringLiteral("gimbot"), this);
    sni->setTitle(QStringLiteral("Gimbot"));
    sni->setIconByName(QStringLiteral("gimbot-symbolic"));
    sni->setCategory(KStatusNotifierItem::Hardware);
    sni->setStatus(KStatusNotifierItem::Active);
    sni->setStandardActionsEnabled(false);
    sni->setContextMenu(m_menu); // takes ownership of the menu
    connect(sni, &KStatusNotifierItem::activateRequested, this, [this](bool, const QPoint &) { emit showRequested(); });
    m_tray = sni;
    m_menuOwnedByTray = true;
    m_trayAvailable = true;
#else
    if (!QSystemTrayIcon::isSystemTrayAvailable()) return;
    auto *icon = new QSystemTrayIcon(QIcon::fromTheme("gimbot-symbolic", QIcon::fromTheme("gimbot")), this);
    icon->setToolTip(QStringLiteral("Gimbot"));
    icon->setContextMenu(m_menu);
    connect(icon, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason r) {
        if (r == QSystemTrayIcon::Trigger || r == QSystemTrayIcon::DoubleClick) emit showRequested();
    });
    icon->show();
    m_tray = icon;
    m_trayAvailable = true;
#endif
    emit trayChanged();
}

void Platform::rebuildMenu()
{
    m_menu->clear();
    m_menu->addAction(QIcon::fromTheme("gimbot"), tr("Open Gimbot"), this, &Platform::showRequested);
    m_menu->addSeparator();
    if (!m_cam->connected()) {
        m_menu->addAction(tr("No camera connected"))->setEnabled(false);
    } else {
        const auto v = m_cam->values();
        const bool asleep = v.value("asleep").toBool();
        m_menu->addAction(asleep ? tr("Wake camera") : tr("Sleep camera"), this,
                          [this, asleep] { m_cam->set("asleep", !asleep); });
        auto *track = m_menu->addMenu(tr("Tracking"));
        auto *group = new QActionGroup(track);
        const QList<QPair<QString, int>> modes = {{tr("Off"), 0},        {tr("Person"), 2}, {tr("Group"), 1},
                                                  {tr("Hand"), 3},       {tr("Desk"), 5},   {tr("Whiteboard"), 4}};
        for (const auto &m : modes) {
            auto *a = track->addAction(m.first, this, [this, mode = m.second] { m_cam->set("mode", mode); });
            a->setCheckable(true);
            a->setChecked(v.value("mode").toInt() == m.second);
            group->addAction(a);
        }
        const auto presets = m_cam->presets();
        if (!presets.isEmpty()) {
            auto *pm = m_menu->addMenu(tr("Presets"));
            for (const auto &p : presets) {
                const auto map = p.toMap();
                pm->addAction(map.value("name").toString(), this,
                              [this, id = map.value("id").toInt()] { m_cam->goToPreset(id); });
            }
        }
        m_menu->addAction(tr("Recenter"), m_cam, &Controller::recenter);
    }
    m_menu->addSeparator();
    m_menu->addAction(tr("Settings…"), this, [this] {
        emit showRequested();
        emit pageRequested("settings");
    });
    m_menu->addAction(QIcon::fromTheme("application-exit"), tr("Quit"), this, &Platform::quitRequested);
}

// ---------------------------------------------------------------- shortcuts

void Platform::setupShortcuts()
{
#ifdef GIMBOT_HAVE_KF6
    // Registered without default keys; the user assigns them in
    // System Settings › Shortcuts › Gimbot.
    auto add = [this](const QString &name, const QString &text, auto fn) {
        auto *a = new QAction(text, this);
        a->setObjectName(name);
        a->setProperty("componentName", QStringLiteral("gimbot"));
        connect(a, &QAction::triggered, this, fn);
        KGlobalAccel::self()->setGlobalShortcut(a, QList<QKeySequence>{});
    };
    add("toggle-tracking", tr("Turn tracking on or off"), [this] { m_cam->toggleTracking(); });
    add("toggle-sleep", tr("Sleep or wake the camera"),
        [this] { m_cam->set("asleep", !m_cam->values().value("asleep").toBool()); });
    add("recenter", tr("Recenter the camera"), [this] { m_cam->recenter(); });
    add("zoom-in", tr("Zoom in"), [this] { m_cam->zoomBy(10); });
    add("zoom-out", tr("Zoom out"), [this] { m_cam->zoomBy(-10); });
    for (int i = 0; i < 3; ++i)
        add(QStringLiteral("preset-%1").arg(i + 1), tr("Go to preset %1").arg(i + 1),
            [this, i] { m_cam->goToPresetIndex(i); });
    add("show-window", tr("Show Gimbot"), [this] { emit showRequested(); });
#endif
}

// ---------------------------------------------------------------- bug reports

QString Platform::diagnostics(bool includeSerial) const
{
    QStringList out;
    out << QStringLiteral("Gimbot %1 (OBSBOT SDK %2, Qt %3, built with Qt %4)")
               .arg(version(), sdkVersion(), qtVersion(), QStringLiteral(QT_VERSION_STR));
    out << QStringLiteral("KDE integration: %1").arg(kdeIntegration() ? "yes" : "no");
    out << QStringLiteral("System: %1").arg(system());
    if (m_cam->connected()) {
        out << QStringLiteral("Camera: %1, firmware %2%3")
                   .arg(m_cam->model(), m_cam->firmware(),
                        includeSerial ? QStringLiteral(", serial ") + m_cam->serial() : QString());
        const auto v = m_cam->values();
        out << QStringLiteral("State: tracking mode %1, zoom %2%, %3")
                   .arg(v.value("mode").toInt())
                   .arg(v.value("zoom").toInt())
                   .arg(v.value("asleep").toBool() ? "asleep" : "awake");
    } else {
        out << QStringLiteral("Camera: not connected%1").arg(m_cam->usbAvailable() ? "" : " (no USB bus found)");
    }
    out << QString() << QStringLiteral("Recent log:");
    out << Logger::recent(80);
    return out.join('\n');
}

void Platform::copyToClipboard(const QString &text) { QGuiApplication::clipboard()->setText(text); }

bool Platform::openIssue(const QString &title, const QString &description, bool includeSerial)
{
    if (m_repo.isEmpty()) return false;
    QString body = QStringLiteral("### What happened?\n%1\n\n### Details\n```\n%2\n```\n")
                       .arg(description.trimmed().isEmpty() ? QStringLiteral("(describe the problem)") : description,
                            diagnostics(includeSerial));
    // Browsers and GitHub limit URL length; keep the newest part of the log.
    if (body.size() > 6000) body = body.left(5990) + "\n```\n";
    QUrl url(QStringLiteral("https://github.com/%1/issues/new").arg(m_repo));
    QUrlQuery q;
    q.addQueryItem("title", title.trimmed().isEmpty() ? QStringLiteral("Problem report") : title.trimmed());
    q.addQueryItem("body", body);
    url.setQuery(q);
    return QDesktopServices::openUrl(url);
}

void Platform::openLogFolder() { QDesktopServices::openUrl(QUrl::fromLocalFile(Logger::logDir())); }
void Platform::openUrl(const QString &url) { QDesktopServices::openUrl(QUrl(url)); }

// ---------------------------------------------------------------- D-Bus

DBusService::DBusService(Controller *cam, Platform *platform, QObject *parent)
    : QObject(parent), m_cam(cam), m_platform(platform)
{
}

void DBusService::Activate() { emit m_platform->showRequested(); }

int DBusService::Run(const QStringList &args, QString &output)
{
    // Answer later, once the camera has replied on the worker thread.
    setDelayedReply(true);
    const QDBusMessage request = message();
    m_cam->runCommand(args, [request](int code, const QString &text) {
        QDBusConnection::sessionBus().send(request.createReply(QVariantList{code, text}));
    });
    output.clear();
    return 0;
}
