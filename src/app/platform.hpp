// Desktop integration: tray icon, system-wide shortcuts, autostart, crash
// detection, bug reports and the D-Bus interface used by gimbotctl.
// Uses KDE Frameworks when they were found at build time (GIMBOT_HAVE_KF6),
// and plain Qt otherwise.
#pragma once

#include <QDBusContext>
#include <QCameraDevice>
#include <QCameraFormat>
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
    // The OBSBOT SDK zip kept in Gimbot's folder, and a newer one found in Downloads.
    Q_PROPERTY(QString sdkFolder READ sdkFolder CONSTANT)
    Q_PROPERTY(QString savedSdk READ savedSdk NOTIFY sdkChanged)
    Q_PROPERTY(QString newSdkPath READ newSdkPath NOTIFY sdkChanged)
    Q_PROPERTY(QString newSdkVersion READ newSdkVersion NOTIFY sdkChanged)

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
    QString sdkFolder() const;
    QString savedSdk() const;
    QString newSdkPath() const { return m_newSdkPath; }
    QString newSdkVersion() const { return m_newSdkVersion; }

    // "libdev_v2.1.0_8.zip" -> "2.1.0_8"; compare like versions.
    static QString sdkVersionOf(const QString &fileName);
    static int compareSdk(const QString &a, const QString &b);

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
    // Look in Downloads for an SDK newer than the one Gimbot uses.
    Q_INVOKABLE void checkForNewSdk();
    // Move an SDK zip (path or file:// URL) into Gimbot's folder, replacing
    // the older one. Returns false (with an error notice) if it isn't an SDK.
    Q_INVOKABLE bool adoptSdk(const QString &pathOrUrl);
    Q_INVOKABLE void openSdkFolder();
    // The sharpest smooth video format for the preview (see previewformat.hpp).
    Q_INVOKABLE QCameraFormat previewFormat(const QCameraDevice &device, int targetHeight, int quality) const;

signals:
    void showRequested();
    void pageRequested(const QString &page);
    void quitRequested();
    void trayChanged();
    void crashChanged();
    void sdkChanged();
    void notice(const QString &message);
    void error(const QString &message);

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
    QString m_newSdkPath, m_newSdkVersion;
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
