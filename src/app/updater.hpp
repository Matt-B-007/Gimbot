// SPDX-License-Identifier: MIT
// Checks GitHub for a newer Gimbot and installs it.
//
// Checking reads the project's releases: channel 1 follows normal releases,
// 2 also beta releases, 0 never checks. Installing runs gimbot-update (the
// same script as the one-line installer), which builds the new version with
// the user's saved OBSBOT SDK, then installs it through pacman with one
// password prompt. Progress comes back as "::progress N message" lines.
#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QQmlEngine;
class QJSEngine;

class Updater : public QObject
{
    Q_OBJECT
    // QML sees the app's single instance as `Updater` (see qmlsingletons.cpp).
    QML_NAMED_ELEMENT(Updater)
    QML_SINGLETON

public:
    static Updater *create(QQmlEngine *, QJSEngine *);

private:
    Q_PROPERTY(bool configured READ configured CONSTANT)
    Q_PROPERTY(QString state READ state NOTIFY changed) // idle checking upToDate available error off
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString latestUrl READ latestUrl NOTIFY changed)
    Q_PROPERTY(QString latestNotes READ latestNotes NOTIFY changed)
    Q_PROPERTY(bool latestIsBeta READ latestIsBeta NOTIFY changed)
    Q_PROPERTY(bool isSwitch READ isSwitch NOTIFY changed) // going from a beta back to a normal release
    Q_PROPERTY(QString lastChecked READ lastChecked NOTIFY changed)
    // Why the last check failed, in plain words (empty when it worked).
    Q_PROPERTY(QString checkError READ checkError NOTIFY changed)
    // The computer's DNS failed and the check went through a public DNS service.
    Q_PROPERTY(bool usedDnsFallback READ usedDnsFallback NOTIFY changed)
    // Seconds until "Try again" can be pressed after a failed check.
    Q_PROPERTY(int retryIn READ retryIn NOTIFY retryInChanged)

    Q_PROPERTY(bool canInstall READ canInstall CONSTANT)
    // "script" (one-line installer), "aur" or "manual" (built by hand).
    Q_PROPERTY(QString installType READ installType CONSTANT)
    Q_PROPERTY(QString aurCommand READ aurCommand CONSTANT)
    // The version Go back would reinstall, or empty if none is saved.
    Q_PROPERTY(QString previousVersion READ previousVersion NOTIFY installChanged)
    Q_PROPERTY(QString installState READ installState NOTIFY installChanged) // idle running done failed
    Q_PROPERTY(int installProgress READ installProgress NOTIFY installChanged)
    Q_PROPERTY(QString installStatus READ installStatus NOTIFY installChanged)
    Q_PROPERTY(QString installError READ installError NOTIFY installChanged)
    Q_PROPERTY(QString installLog READ installLog NOTIFY installChanged)
    Q_PROPERTY(QString installAction READ installAction NOTIFY installChanged) // update rebuild uninstall

public:
    Updater(const QString &repo, const QString &currentVersion, QObject *parent = nullptr);

    bool configured() const { return !m_repo.isEmpty(); }
    QString state() const { return m_state; }
    QString latestVersion() const { return m_latest; }
    QString latestUrl() const { return m_url; }
    QString latestNotes() const { return m_notes; }
    bool latestIsBeta() const { return m_beta; }
    bool isSwitch() const { return m_switch; }
    QString lastChecked() const { return m_lastChecked; }
    QString checkError() const { return m_checkError; }
    bool usedDnsFallback() const { return m_dnsFallback; }
    int retryIn() const { return m_retryIn; }

    // AUR installs update through the AUR helper, not here.
    bool canInstall() const { return m_simulated || (!m_helper.isEmpty() && configured() && m_installType != "aur"); }
    QString installType() const { return m_installType; }
    QString aurCommand() const;
    QString previousVersion() const;
    static QString packagesDir(); // ~/.local/share/gimbot/packages (current + previous)
    QString installState() const { return m_installState; }
    int installProgress() const { return m_progress; }
    QString installStatus() const { return m_status; }
    QString installError() const { return m_error; }
    QString installLog() const { return m_log; }
    QString installAction() const { return m_action; }

    void setChannel(int channel);
    int channel() const { return m_channel; }
    // A check the user asked for (a button). Automatic checks use autoCheck().
    Q_INVOKABLE void check();
    void autoCheck();
    // For the screenshot tour: pretend the check failed because of DNS.
    Q_INVOKABLE void simulateCheckError();
    Q_INVOKABLE void install();
    // Rebuild the installed version, e.g. with a newer OBSBOT SDK.
    Q_INVOKABLE void rebuild();
    // Remove Gimbot; purge also deletes settings, logs and the saved SDK.
    Q_INVOKABLE void uninstall(bool purge);
    // Reinstall the previously installed version (kept by the installer).
    Q_INVOKABLE void rollback();
    Q_INVOKABLE void cancelInstall();
    Q_INVOKABLE void restartApp();
    // For testing the update screens: --fake runs a pretend update.
    void setSimulated(bool on) { m_simulated = on; }

    // -1, 0, 1 like strcmp; understands "1.2.0-beta.3".
    static int compareVersions(const QString &a, const QString &b);
    // One version's notes from CHANGELOG.md (for What's new).
    static QString changelogSection(const QByteArray &changelog, const QString &version);

    // Which version to offer, from the signed releases in the releases list.
    struct Choice {
        bool valid = false;  // the releases answer made sense
        QString version;     // empty: nothing to offer
        QString tag;         // release tag
        QJsonObject release; // the chosen release, if any
        bool beta = false, isSwitch = false;
    };
    static Choice choose(const QByteArray &releasesJson, const QString &current, int channel);
    // A release counts only with its source, SHA256SUMS and signature attached.
    static bool isSigned(const QJsonObject &release);

signals:
    // A check failed. manual: the user asked for it, so tell them right away.
    void checkFailed(const QString &message, bool manual);
    void retryInChanged();
    void changed();
    void installChanged();

private:
    void setState(const QString &s);
    void readOutput();
    void run(const QString &action, const QStringList &args);
    void startCheck(bool manual);
    // Download url; if the computer can't look up names, retry through public
    // DNS with curl. done(ok, data, plain-language error).
    void fetch(const QString &url, bool json, std::function<void(bool, const QByteArray &, const QString &)> done);
    void fetchWithCurl(const QString &url, bool json, int dohIndex,
                       std::function<void(bool, const QByteArray &, const QString &)> done);
    void decide(const QByteArray &releasesJson);
    static QString readInstallType();
    void fail(const QString &message);

    QNetworkAccessManager m_net;
    QTimer m_timer;
    QString m_repo, m_current, m_helper, m_installType;
    int m_channel = 1;
    QString m_state = "idle", m_latest, m_tag, m_url, m_notes, m_lastChecked;
    bool m_beta = false, m_switch = false, m_simulated = false;
    QString m_checkError;
    bool m_dnsFallback = false;
    bool m_manual = false;    // the check in progress was asked for
    qint64 m_lastAttempt = 0; // ms since epoch
    int m_failures = 0;       // in a row, for backing off
    QTimer m_retry;
    QTimer m_cooldown; // ticks retryIn down once a second
    int m_retryIn = 0;
    int m_curlExit = 0; // last backup lookup's curl exit code

    QProcess *m_proc = nullptr;
    QString m_installState = "idle", m_status, m_error, m_log, m_action = "update";
    int m_progress = 0;
    QByteArray m_partial;
};
