#include "updater.hpp"

#include <QFile>
#include <QDir>
#include <QFileInfo>
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
    m_cooldown.setInterval(1000);
    connect(&m_cooldown, &QTimer::timeout, this, [this] {
        if (--m_retryIn <= 0) {
            m_retryIn = 0;
            m_cooldown.stop();
        }
        emit retryInChanged();
    });
    if (!configured()) m_state = "off";
    m_helper = QStandardPaths::findExecutable("gimbot-update");
    m_installType = readInstallType();
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
    // Right after a failed check, "Try again" waits out a short cooldown
    // (the button shows the countdown); right after a good answer, pressing
    // again just keeps that answer.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (manual && m_retryIn > 0) return;
    if (now - m_lastAttempt < 5000) return;
    m_lastAttempt = now;
    m_manual = manual;
    m_retry.stop();
    m_dnsFallback = false;
    setState("checking");

    // Published releases only. A release counts once its source, checksums
    // and signature are attached (the installer verifies them).
    fetch(QStringLiteral("https://api.github.com/repos/%1/releases?per_page=30").arg(m_repo), true,
          [this](bool ok, const QByteArray &releases, const QString &error) {
              if (!ok) {
                  fail(error);
                  return;
              }
              decide(releases);
          });
}

void Updater::fetch(const QString &url, bool json, std::function<void(bool, const QByteArray &, const QString &)> done)
{
    QNetworkRequest req{QUrl(url)};
    if (json) req.setRawHeader("Accept", "application/vnd.github+json");
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray("Gimbot/") + m_current.toUtf8());
    req.setTransferTimeout(15000);
    auto *reply = m_net.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, url, json, done] {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto err = reply->error();
        if (err == QNetworkReply::NoError) {
            done(true, reply->readAll(), QString());
            return;
        }
        qWarning().noquote() << "Couldn't fetch" << url << ":" << reply->errorString();
        if (err == QNetworkReply::HostNotFoundError) {
            fetchWithCurl(url, json, 0, done); // the computer can't look up names: try public DNS
            return;
        }
        QString why;
        if (http == 403 || http == 429)
            why = tr("GitHub is limiting update checks right now. Gimbot will try again later.");
        else if (http == 404)
            why = tr("Gimbot's page on GitHub wasn't found.");
        else if (err == QNetworkReply::TimeoutError || err == QNetworkReply::OperationCanceledError)
            why = tr("GitHub took too long to answer. Check your internet connection.");
        else if (err == QNetworkReply::SslHandshakeFailedError)
            why = tr("Couldn't make a secure connection to GitHub. Check the computer's date and time.");
        else
            why = tr("Can't reach GitHub. Check your internet connection.");
        done(false, {}, why);
    });
}

void Updater::fetchWithCurl(const QString &url, bool json, int dohIndex,
                            std::function<void(bool, const QByteArray &, const QString &)> done)
{
    static const QStringList doh = {QStringLiteral("https://1.1.1.1/dns-query"), QStringLiteral("https://8.8.8.8/dns-query")};
    const QString curl = QStandardPaths::findExecutable("curl");
    if (dohIndex == 0) m_curlExit = 0;
    if (curl.isEmpty() || dohIndex >= doh.size()) {
        // 7 = couldn't connect, 28 = timed out: the backup couldn't get out
        // either, so it's the connection, not just DNS.
        if (m_curlExit == 7 || m_curlExit == 28)
            done(false, {}, tr("This computer isn't connected to the internet right now, so Gimbot can't reach GitHub."));
        else
            done(false, {}, tr("This computer can't look up web addresses (DNS isn't working), so Gimbot can't reach GitHub. "
                               "Other apps are probably affected too."));
        return;
    }
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, url, json, dohIndex, done](int code, QProcess::ExitStatus status) {
        proc->deleteLater();
        if (status == QProcess::NormalExit && code == 0) {
            qInfo() << "Fetched" << url << "through" << doh[dohIndex] << "because the computer's DNS failed";
            m_dnsFallback = true;
            done(true, proc->readAllStandardOutput(), QString());
            return;
        }
        // Say why, so a bug report shows the cause (curl exit codes: 6 name
        // lookup, 7 couldn't connect, 28 timeout, 35/60 TLS problem).
        const QString why = QString::fromUtf8(proc->readAllStandardError()).trimmed().section('\n', -1);
        m_curlExit = status == QProcess::NormalExit ? code : -1;
        qWarning().noquote() << QStringLiteral("Backup lookup through %1 failed: curl exit %2%3")
                                    .arg(doh[dohIndex])
                                    .arg(m_curlExit)
                                    .arg(why.isEmpty() ? QString() : ": " + why);
        fetchWithCurl(url, json, dohIndex + 1, done);
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, url, json, done](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart) return; // finished() handles the rest
        qWarning() << "Couldn't run curl for the backup lookup";
        proc->deleteLater();
        fetchWithCurl(url, json, int(doh.size()), done);
    });
    QStringList args = {"-fsSL", "-S", "--max-time", "20", "--doh-url", doh[dohIndex], "-A", "Gimbot/" + m_current};
    if (json) args << "-H" << "Accept: application/vnd.github+json";
    proc->start(curl, args << url);
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
    // Only automatic failures lengthen the wait; pressing Try again doesn't.
    if (!m_manual || !m_retry.isActive()) m_retry.start(wait * 60 * 1000);
    qWarning().noquote() << "Update check:" << message
                         << QStringLiteral("(trying again in %1 min)").arg((m_retry.remainingTime() + 59999) / 60000);
    if (!m_manual) ++m_failures;
    m_retryIn = 30;
    m_cooldown.start();
    emit retryInChanged();
    setState("error");
    emit checkFailed(message, m_manual);
}

QString Updater::changelogSection(const QByteArray &changelog, const QString &version)
{
    // "## 0.1.0-beta.7 ..." up to the next "## " heading.
    const QStringList lines = QString::fromUtf8(changelog).split('\n');
    QStringList out;
    bool in = false;
    for (const QString &line : lines) {
        if (line.startsWith("## ")) {
            if (in) break;
            // First word of the heading, so 0.1.0-beta.1 doesn't match beta.10.
            QString first = line.mid(3).trimmed().section(' ', 0, 0);
            if (first.startsWith('v')) first = first.mid(1);
            in = first == version;
            continue;
        }
        if (in) out << line;
    }
    return out.join('\n').trimmed();
}

bool Updater::isSigned(const QJsonObject &release)
{
    // Source, checksums and signature, as the release workflow attaches them.
    const QString version = release.value("tag_name").toString().mid(1);
    bool source = false, sums = false, sig = false;
    for (const auto &a : release.value("assets").toArray()) {
        const QString name = a.toObject().value("name").toString();
        source |= name == QStringLiteral("Gimbot-%1-source.tar.gz").arg(version);
        sums |= name == QLatin1String("SHA256SUMS");
        sig |= name == QLatin1String("SHA256SUMS.minisig");
    }
    return source && sums && sig;
}

Updater::Choice Updater::choose(const QByteArray &releasesJson, const QString &current, int channel)
{
    Choice c;
    const auto doc = QJsonDocument::fromJson(releasesJson);
    if (!doc.isArray()) return c;
    c.valid = true;
    QString best;
    QJsonObject bestObj;
    for (const auto &v : doc.array()) {
        const auto o = v.toObject();
        if (o.value("draft").toBool()) continue;
        if (o.value("prerelease").toBool() && channel < 2) continue;
        if (!isSigned(o)) continue; // not available yet (or from before signing started)
        const QString tag = o.value("tag_name").toString();
        if (best.isEmpty() || compareVersions(tag, best) > 0) {
            best = tag;
            bestObj = o;
        }
    }
    const QString version = best.startsWith('v') ? best.mid(1) : best;
    // On a beta but following normal releases again: offer the newest
    // normal release even though its number is lower.
    const bool onBeta = current.contains('-');
    c.isSwitch = !version.isEmpty() && channel == 1 && onBeta && compareVersions(version, current) < 0;
    if (version.isEmpty() || (compareVersions(version, current) <= 0 && !c.isSwitch)) return c;
    c.version = version;
    c.tag = best;
    c.release = bestObj;
    c.beta = bestObj.value("prerelease").toBool();
    return c;
}

void Updater::decide(const QByteArray &releasesJson)
{
    m_lastChecked = QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
    const Choice c = choose(releasesJson, m_current, m_channel);
    if (!c.valid) {
        fail(tr("GitHub sent an answer Gimbot didn't understand. It will try again later."));
        return;
    }
    m_failures = 0;
    m_checkError.clear();
    m_switch = c.isSwitch;
    if (c.version.isEmpty()) {
        setState("upToDate");
        return;
    }
    m_latest = c.version;
    m_tag = c.tag;
    m_beta = c.beta;
    m_url = c.release.value("html_url").toString();
    m_notes = c.release.value("body").toString().left(6000);
    qInfo() << "Update available:" << m_latest << (m_beta ? "(beta)" : "") << (m_switch ? "(switch)" : "");
    setState("available");
}

// ---------------------------------------------------------------- how Gimbot was installed

QString Updater::readInstallType()
{
#ifdef GIMBOT_LIBDIR
    QFile f(QStringLiteral(GIMBOT_LIBDIR "/gimbot/install-type"));
    if (f.open(QIODevice::ReadOnly)) {
        const QString t = QString::fromUtf8(f.readAll()).trimmed();
        if (t == "aur" || t == "script") return t;
    }
#endif
    return QStringLiteral("manual");
}

QString Updater::packagesDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/gimbot/packages";
}

QString Updater::previousVersion() const
{
    // The installer keeps previous/<package file> + previous/version.
    const QDir dir(packagesDir() + "/previous");
    if (dir.entryList({"*.pkg.tar*"}, QDir::Files).isEmpty()) return {};
    QFile f(dir.filePath("version"));
    if (!f.open(QIODevice::ReadOnly)) return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}

QString Updater::aurCommand() const
{
    return m_current.contains('-') ? QStringLiteral("paru -Syu gimbot-beta") : QStringLiteral("paru -Syu gimbot");
}

void Updater::rollback() { run("rollback", {"--gui", "--rollback"}); }

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
                       : m_action == "rollback" ? tr("Went back to the previous version")
                                               : tr("Gimbot %1 is installed").arg(m_latest);
            qInfo().noquote() << m_action << "finished";
        } else {
            m_installState = "failed";
            if (m_error.isEmpty())
                m_error = code == 3 ? tr("The OBSBOT SDK zip wasn't found.")
                          : m_action == "uninstall" ? tr("Uninstalling didn't finish.")
                          : m_action == "rollback" ? tr("Going back didn't finish.")
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
