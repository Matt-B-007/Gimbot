// SPDX-License-Identifier: MIT
#include "platform.hpp"
#include "previewformat.hpp"

#include <QVideoFrameFormat>

#include "controller.hpp"
#include "crashlog.hpp"
#include "logger.hpp"
#include "redact.hpp"
#include "trayicon.hpp"
#include "updater.hpp"
#include <QDateTime>
#include <QSaveFile>

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
#include <QPalette>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QSysInfo>
#include <QSystemTrayIcon>
#include <QTimer>
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
{}

Platform::~Platform()
{
    if (!m_menuOwnedByTray) delete m_menu;
}

QString Platform::version() const
{
    return QStringLiteral(GIMBOT_VERSION);
}
QString Platform::sdkVersion() const
{
    return QStringLiteral(GIMBOT_SDK_VERSION);
}
QString Platform::qtVersion() const
{
    return QString::fromLatin1(qVersion());
}
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
QString Platform::repoUrl() const
{
    return m_repo.isEmpty() ? QString() : "https://github.com/" + m_repo;
}
bool Platform::reduceMotion() const
{
    const QString file = QStandardPaths::locate(QStandardPaths::GenericConfigLocation, QStringLiteral("kdeglobals"));
    if (file.isEmpty()) return false;
    QSettings kde(file, QSettings::IniFormat);
    return kde.value(QStringLiteral("KDE/AnimationDurationFactor"), 1.0).toDouble() <= 0.0;
}

bool Platform::repoPublic() const
{
#ifdef GIMBOT_REPO_PRIVATE
    return false;
#else
    return true;
#endif
}
QString Platform::logFile() const
{
    return Logger::logFile();
}

// ---------------------------------------------------------------- OBSBOT SDK folder

QString Platform::sdkFolder() const
{
    // Same place the installer keeps it.
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/gimbot/sdk";
}

QString Platform::savedSdk() const
{
    const auto list = QDir(sdkFolder()).entryList({"libdev*.zip"}, QDir::Files);
    QString best;
    for (const auto &f : list)
        if (best.isEmpty() || compareSdk(sdkVersionOf(f), sdkVersionOf(best)) > 0) best = f;
    return best;
}

QString Platform::sdkVersionOf(const QString &fileName)
{
    static const QRegularExpression re(QStringLiteral("^libdev_?v?([0-9][0-9A-Za-z._-]*)\\.zip$"));
    const auto m = re.match(QFileInfo(fileName).fileName());
    return m.hasMatch() ? m.captured(1) : QString();
}

int Platform::compareSdk(const QString &a, const QString &b)
{
    static const QRegularExpression nonDigits(QStringLiteral("[^0-9]+"));
    const auto pa = a.split(nonDigits, Qt::SkipEmptyParts), pb = b.split(nonDigits, Qt::SkipEmptyParts);
    for (int i = 0; i < std::max(pa.size(), pb.size()); ++i) {
        const int x = i < pa.size() ? pa[i].toInt() : 0, y = i < pb.size() ? pb[i].toInt() : 0;
        if (x != y) return x < y ? -1 : 1;
    }
    return 0;
}

void Platform::checkForNewSdk()
{
    // Newer than both the SDK Gimbot was built with and the saved one.
    QString floor = sdkVersion();
    const QString saved = sdkVersionOf(savedSdk());
    if (!saved.isEmpty() && compareSdk(saved, floor) > 0) floor = saved;
    QString bestPath, bestVersion;
    const QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    QStringList candidates;
    for (const auto &f : QDir(downloads).entryInfoList({"libdev*.zip"}, QDir::Files))
        candidates << f.absoluteFilePath();
    for (const auto &sub : QDir(downloads).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot))
        for (const auto &f : QDir(sub.absoluteFilePath()).entryInfoList({"libdev*.zip"}, QDir::Files))
            candidates << f.absoluteFilePath();
    for (const auto &path : candidates) {
        const QString v = sdkVersionOf(path);
        if (v.isEmpty()) continue;
        const bool newer =
            floor == QLatin1String("none") || floor == QLatin1String("unknown") || compareSdk(v, floor) > 0;
        if (newer && (bestVersion.isEmpty() || compareSdk(v, bestVersion) > 0)) {
            bestPath = path;
            bestVersion = v;
        }
    }
    if (bestPath != m_newSdkPath) {
        m_newSdkPath = bestPath;
        m_newSdkVersion = bestVersion;
        if (!bestPath.isEmpty()) qInfo() << "Found a newer OBSBOT SDK:" << bestPath;
        emit sdkChanged();
    }
}

bool Platform::adoptSdk(const QString &pathOrUrl)
{
    const QUrl url(pathOrUrl);
    const QString path = url.isLocalFile() ? url.toLocalFile() : pathOrUrl;
    const QFileInfo info(path);
    if (!info.isFile() || sdkVersionOf(info.fileName()).isEmpty()) {
        emit error(tr("That isn't an OBSBOT SDK zip. It should be named like libdev_v2.1.0_8.zip."));
        return false;
    }
    QDir().mkpath(sdkFolder());
    const QString target = sdkFolder() + "/" + info.fileName();
    if (QFileInfo(target).absoluteFilePath() != info.absoluteFilePath()) {
        QFile::remove(target);
        if (!QFile::rename(path, target)) { // different drive: copy, then remove
            if (!QFile::copy(path, target)) {
                emit error(tr("Couldn't move the SDK into %1.").arg(sdkFolder()));
                return false;
            }
            QFile::remove(path);
        }
    }
    // Keep only the newest.
    for (const auto &f : QDir(sdkFolder()).entryList({"libdev*.zip"}, QDir::Files))
        if (f != info.fileName() && compareSdk(sdkVersionOf(f), sdkVersionOf(info.fileName())) <= 0)
            QFile::remove(sdkFolder() + "/" + f);
    qInfo() << "Moved the OBSBOT SDK to" << target;
    emit notice(tr("Moved %1 into Gimbot's folder").arg(info.fileName()));
    m_newSdkPath.clear();
    m_newSdkVersion.clear();
    emit sdkChanged();
    checkForNewSdk();
    return true;
}

void Platform::openSdkFolder()
{
    QDir().mkpath(sdkFolder());
    QDesktopServices::openUrl(QUrl::fromLocalFile(sdkFolder()));
}

// ---------------------------------------------------------------- crash detection

void Platform::markRunning()
{
    QDir().mkpath(QFileInfo(markerPath()).path());
    m_crashed = QFile::exists(markerPath());
    if (m_crashed) qWarning() << "The previous session did not exit cleanly";
    QFile f(markerPath());
    if (f.open(QIODevice::WriteOnly)) f.write(QByteArray::number(QCoreApplication::applicationPid()));
}

void Platform::markCleanExit()
{
    QFile::remove(markerPath());
}

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
    // Keep the icon's state up to date.
    auto *problemTimer = new QTimer(this);
    problemTimer->setSingleShot(true);
    problemTimer->setInterval(60 * 1000);
    connect(problemTimer, &QTimer::timeout, this, [this] {
        m_problem = false;
        updateTrayState();
    });
    connect(m_cam, &Controller::errorOccurred, this, [this, problemTimer] {
        m_problem = true;
        problemTimer->start();
        updateTrayState();
    });
    connect(this, &Platform::showRequested, this, [this, problemTimer] {
        // Opening the window is how the user sees the error, so clear the dot.
        if (!m_problem) return;
        m_problem = false;
        problemTimer->stop();
        updateTrayState();
    });
    connect(m_cam, &Controller::connectedChanged, this, &Platform::updateTrayState);
    connect(m_cam, &Controller::valuesChanged, this, &Platform::updateTrayState);
    connect(m_cam, &Controller::trackingPausedChanged, this, &Platform::updateTrayState);
    connect(m_updater, &Updater::changed, this, &Platform::updateTrayState);
    qApp->installEventFilter(this); // redraw when the panel's colors change
    updateTrayState();
    emit trayChanged();
}

bool Platform::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == qApp && event->type() == QEvent::ApplicationPaletteChange) {
        m_trayState.clear();
        updateTrayState();
    }
    return QObject::eventFilter(watched, event);
}

void Platform::updateTrayState()
{
    if (!m_tray) return;
    trayicon::Inputs in;
    in.connected = m_cam->connected();
    in.problem = m_problem;
    const auto v = m_cam->values();
    in.muted = v.value("asleep").toBool() || m_cam->trackingPaused();
    in.updateReady = m_updater->state() == QLatin1String("available");
    in.tracking = v.value("mode").toInt() != 0;
    const auto state = trayicon::stateFor(in);
    const QString name = trayicon::name(state);
    if (name == m_trayState) return;
    m_trayState = name;

    const QColor plain = QGuiApplication::palette().color(QPalette::WindowText);
    QIcon icon;
    for (int size : {16, 22, 24, 32, 48, 64}) icon.addPixmap(QPixmap::fromImage(trayicon::render(state, plain, size)));
    const QString tip = trayicon::tooltip(state);
#ifdef GIMBOT_HAVE_KF6
    auto *sni = static_cast<KStatusNotifierItem *>(m_tray);
    if (state == trayicon::State::Idle) {
        sni->setIconByName(QStringLiteral("gimbot-symbolic")); // follows the Plasma theme exactly
    } else {
        sni->setIconByPixmap(icon);
    }
    sni->setToolTip(QStringLiteral("gimbot-symbolic"), QStringLiteral("Gimbot"), tip);
    // Plasma hides Passive items in the overflow; anything needing a look is NeedsAttention.
    sni->setStatus(state == trayicon::State::Problem || state == trayicon::State::Attention
                       ? KStatusNotifierItem::NeedsAttention
                       : KStatusNotifierItem::Active);
#else
    auto *tray = static_cast<QSystemTrayIcon *>(m_tray);
    tray->setIcon(icon);
    tray->setToolTip(QStringLiteral("Gimbot: ") + tip);
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
        const int mode = v.value("mode").toInt();
        auto *onOff = m_menu->addAction(tr("Tracking"), m_cam, &Controller::toggleTracking);
        onOff->setCheckable(true);
        onOff->setChecked(mode != 0);
        if (m_cam->trackingPaused()) m_menu->addAction(tr("Resume tracking"), m_cam, &Controller::resumeTracking);
        auto *track = m_menu->addMenu(tr("Tracking mode"));
        auto *group = new QActionGroup(track);
        const QList<QPair<QString, int>> modes = {
            {tr("Person"), 2}, {tr("Group"), 1}, {tr("Hand"), 3}, {tr("Desk"), 5}, {tr("Whiteboard"), 4}};
        const int shown = mode != 0 ? mode : v.value("lastTrackingMode").toInt();
        for (const auto &m : modes) {
            auto *a = track->addAction(m.first, this, [this, mode = m.second] { m_cam->set("mode", mode); });
            a->setCheckable(true);
            a->setChecked(shown == m.second);
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
#ifndef GIMBOT_KDE_STATUS
#define GIMBOT_KDE_STATUS "unknown"
#endif
    out << QStringLiteral("KDE integration: %1 (%2)")
               .arg(kdeIntegration() ? "yes" : "no", QStringLiteral(GIMBOT_KDE_STATUS));
    out << QStringLiteral("System: %1").arg(system());
    out << QStringLiteral("Updates: %1, installed %2")
               .arg(m_updater->channel() == 2   ? "beta"
                    : m_updater->channel() == 1 ? "stable"
                                                : "off",
                    m_updater->installType() == QLatin1String("aur")      ? "from the AUR"
                    : m_updater->installType() == QLatin1String("script") ? "with install.sh"
                                                                          : "by hand");
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
    if (m_crashed) {
        const QString crash = CrashLog::latest();
        if (!crash.isEmpty()) out << QString() << QStringLiteral("Last crash:") << crash.left(4000).trimmed();
    }
    out << QString() << QStringLiteral("Recent log:");
    out << (m_reportFromFile ? Logger::fileTail(80) : Logger::recent(80));
    return redactText(out.join('\n'), includeSerial);
}

QString Platform::redactText(const QString &text, bool includeSerial) const
{
    // Privacy: no home folder, user or computer name, addresses or secrets in
    // reports, and the serial number only when the user ticks the box.
    redact::Context ctx;
    ctx.home = QDir::homePath();
    ctx.user = qEnvironmentVariable("USER");
    ctx.host = QSysInfo::machineHostName();
    if (!includeSerial) ctx.extra.append({m_cam->serial(), QStringLiteral("<serial>")});
    return redact::apply(text, ctx);
}

QString Platform::reportText(const QString &title, const QString &description, bool includeSerial) const
{
    QStringList out;
    out << QStringLiteral("Summary: %1").arg(title.trimmed().isEmpty() ? QStringLiteral("(none)") : title.trimmed());
    out << QStringLiteral("What happened:")
        << (description.trimmed().isEmpty() ? QStringLiteral("(not described)") : description.trimmed());
    out << QString() << diagnostics(includeSerial);
    return redactText(out.join('\n'), includeSerial);
}

QString Platform::saveReport(const QString &title, const QString &description, bool includeSerial)
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty() || !QDir().mkpath(dir)) dir = QDir::homePath();
    const QString path = dir + QStringLiteral("/gimbot-report-%1.txt")
                                   .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit error(tr("Couldn't save the report to %1").arg(dir));
        return {};
    }
    f.write(reportText(title, description, includeSerial).toUtf8());
    f.write("\n");
    if (!f.commit()) {
        emit error(tr("Couldn't save the report to %1").arg(dir));
        return {};
    }
    m_lastReport = path;
    emit reportSaved();
    return path;
}

void Platform::showSavedReport()
{
    if (m_lastReport.isEmpty()) return;
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(m_lastReport).path()));
}

void Platform::copyToClipboard(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

bool Platform::openIssue(const QString &title, const QString &description, bool includeSerial)
{
    if (m_repo.isEmpty()) return false;
    // The issue gets the summary and the header lines only (versions, system,
    // camera). The full report, with the log, is a file the user attaches.
    if (saveReport(title, description, includeSerial).isEmpty()) return false;
    QStringList header;
    for (const QString &line : diagnostics(includeSerial).split('\n')) {
        if (line.isEmpty()) break; // the header ends at the first blank line
        header << line;
    }
    const QString body =
        QStringLiteral("### What happened?\n%1\n\n### Details\n```\n%2\n```\n\n"
                       "### Full report\nPlease attach `%3` (saved in %4) by dragging it into this box.\n")
            .arg(description.trimmed().isEmpty() ? QStringLiteral("(describe the problem)")
                                                 : redactText(description.trimmed(), includeSerial),
                 header.join('\n'), QFileInfo(m_lastReport).fileName(),
                 redactText(QFileInfo(m_lastReport).path(), false));
    QUrl url(QStringLiteral("https://github.com/%1/issues/new").arg(m_repo));
    QUrlQuery q;
    q.addQueryItem("title", title.trimmed().isEmpty() ? QStringLiteral("Problem report")
                                                      : redactText(title.trimmed(), includeSerial));
    q.addQueryItem("body", body);
    url.setQuery(q);
    return QDesktopServices::openUrl(url);
}

void Platform::openLogFolder()
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(Logger::logDir()));
}
void Platform::openUrl(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

// ---------------------------------------------------------------- D-Bus

DBusService::DBusService(Controller *cam, Platform *platform, QObject *parent)
    : QObject(parent), m_cam(cam), m_platform(platform)
{}

void DBusService::Activate()
{
    emit m_platform->showRequested();
}

QString DBusService::SaveReport()
{
    // `gimbot --report` while Gimbot is running: the running copy knows the camera.
    return m_platform->saveReport(QString(), QString(), false);
}

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

static std::vector<preview::Format> formatsOf(const QList<QCameraFormat> &all)
{
    std::vector<preview::Format> list;
    for (const auto &f : all)
        list.push_back({f.resolution().width(), f.resolution().height(), f.maxFrameRate(),
                        f.pixelFormat() == QVideoFrameFormat::Format_Jpeg});
    return list;
}

QCameraFormat Platform::previewFormat(const QCameraDevice &device, int targetHeight, const QString &choice) const
{
    const QList<QCameraFormat> all = device.videoFormats();
    const auto list = formatsOf(all);
    int i = -1;
    // A chosen resolution and frame rate, if this camera offers it…
    static const QRegularExpression re(QStringLiteral("^(\\d+)x(\\d+)@(\\d+)$"));
    const auto m = re.match(choice);
    if (m.hasMatch()) i = preview::find(list, m.captured(1).toInt(), m.captured(2).toInt(), m.captured(3).toInt());
    // …otherwise Auto.
    if (i < 0) i = preview::choose(list, targetHeight, 0);
    if (i < 0) return {};
    qInfo().noquote() << QStringLiteral("Preview format: %1x%2 at %3 fps%4%5")
                             .arg(all[i].resolution().width())
                             .arg(all[i].resolution().height())
                             .arg(all[i].maxFrameRate())
                             .arg(list[size_t(i)].compressed ? QStringLiteral(" (MJPEG)") : QString())
                             .arg(m.hasMatch() ? QString() : QStringLiteral(" (auto)"));
    return all[i];
}

QVariantList Platform::previewChoices(const QCameraDevice &device) const
{
    QVariantList out;
    for (const auto &c : preview::choices(formatsOf(device.videoFormats()))) {
        QVariantMap m;
        m["key"] = QStringLiteral("%1x%2@%3").arg(c.width).arg(c.height).arg(c.fps);
        m["label"] = formatLabel(c.width, c.height, c.fps);
        m["width"] = c.width;
        m["height"] = c.height;
        m["fps"] = c.fps;
        out << m;
    }
    return out;
}

QString Platform::formatLabel(int width, int height, int fps) const
{
    QString res;
    if (width == 3840 && height == 2160)
        res = QStringLiteral("4K");
    else if (width * 9 == height * 16 &&
             (height == 360 || height == 480 || height == 540 || height == 720 || height == 1080 || height == 1440))
        res = QStringLiteral("%1p").arg(height);
    else
        res = QStringLiteral("%1×%2").arg(width).arg(height);
    return fps > 0 ? tr("%1 · %2 fps").arg(res).arg(fps) : res;
}
