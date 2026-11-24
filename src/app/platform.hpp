// Desktop integration: tray icon, system-wide shortcuts, autostart, crash
// detection, bug reports and the D-Bus interface used by gimbotctl.
// Uses KDE Frameworks when they were found at build time (GIMBOT_HAVE_KF6),
// and plain Qt otherwise.
#pragma once

#include <QDBusContext>
#include <QObject>
#include <QStringList>

class Controller;
class Updater;
class QMenu;
class QSystemTrayIcon;

class Platform : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString sdkVersion READ sdkVersion CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString system READ system CONSTANT)
    Q_PROPERTY(bool kdeIntegration READ kdeIntegration CONSTANT)
    Q_PROPERTY(bool trayAvailable READ trayAvailable NOTIFY trayChanged)
    Q_PROPERTY(bool issuesConfigured READ issuesConfigured CONSTANT)
    Q_PROPERTY(QString repoUrl READ repoUrl CONSTANT)
    Q_PROPERTY(bool previousSessionCrashed READ previousSessionCrashed NOTIFY crashChanged)
    Q_PROPERTY(QString logFile READ logFile CONSTANT)

public:
    Platform(Controller *cam, Updater *updater, const QString &repo, QObject *parent = nullptr);
    ~Platform() override;

    QString version() const;
    QString sdkVersion() const;
    QString qtVersion() const;
    QString system() const;
    bool kdeIntegration() const;
    bool trayAvailable() const { return m_trayAvailable; }
    bool issuesConfigured() const { return !m_repo.isEmpty(); }
    QString repoUrl() const;
    bool previousSessionCrashed() const { return m_crashed; }
    QString logFile() const;

    void setupTray();
    void setupShortcuts();
    void markRunning();
    void markCleanExit();
    void applyAutostart(bool on);

    Q_INVOKABLE QString diagnostics(bool includeSerial = false) const;
    Q_INVOKABLE void copyToClipboard(const QString &text);
    Q_INVOKABLE bool openIssue(const QString &title, const QString &description, bool includeSerial);
    Q_INVOKABLE void openLogFolder();
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE void dismissCrash();

signals:
    void showRequested();
    void pageRequested(const QString &page);
    void quitRequested();
    void trayChanged();
    void crashChanged();

private:
    void rebuildMenu();

    Controller *m_cam;
    Updater *m_updater;
    QString m_repo;
    QMenu *m_menu = nullptr;
    QObject *m_tray = nullptr; // KStatusNotifierItem or QSystemTrayIcon
    bool m_trayAvailable = false;
    bool m_menuOwnedByTray = false;
    bool m_crashed = false;
};

// Exposed on the session bus as io.github.Matt_B_007.Gimbot at /Gimbot.
class DBusService : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.Matt_B_007.Gimbot1")
public:
    DBusService(Controller *cam, Platform *platform, QObject *parent = nullptr);

public slots:
    Q_SCRIPTABLE void Activate();
    Q_SCRIPTABLE int Run(const QStringList &args, QString &output);

private:
    Controller *m_cam;
    Platform *m_platform;
};
