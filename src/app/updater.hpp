// Checks the project's GitHub releases for a newer Gimbot. It only tells the
// user; the package manager (paru/yay, Discover) does the actual update.
// Channel 1 = normal releases, 2 = also beta releases, 0 = never check.
#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>

class Updater : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool configured READ configured CONSTANT)
    Q_PROPERTY(QString state READ state NOTIFY changed) // idle checking upToDate available error off
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString latestUrl READ latestUrl NOTIFY changed)
    Q_PROPERTY(QString latestNotes READ latestNotes NOTIFY changed)
    Q_PROPERTY(bool latestIsBeta READ latestIsBeta NOTIFY changed)
    Q_PROPERTY(QString lastChecked READ lastChecked NOTIFY changed)

public:
    Updater(const QString &repo, const QString &currentVersion, QObject *parent = nullptr);

    bool configured() const { return !m_repo.isEmpty(); }
    QString state() const { return m_state; }
    QString latestVersion() const { return m_latest; }
    QString latestUrl() const { return m_url; }
    QString latestNotes() const { return m_notes; }
    bool latestIsBeta() const { return m_beta; }
    QString lastChecked() const { return m_lastChecked; }

    void setChannel(int channel);
    Q_INVOKABLE void check();

    // -1, 0, 1 like strcmp; understands "1.2.0-beta.3".
    static int compareVersions(const QString &a, const QString &b);

signals:
    void changed();

private:
    void setState(const QString &s);

    QNetworkAccessManager m_net;
    QTimer m_timer;
    QString m_repo, m_current;
    int m_channel = 1;
    QString m_state = "idle", m_latest, m_url, m_notes, m_lastChecked;
    bool m_beta = false;
};
