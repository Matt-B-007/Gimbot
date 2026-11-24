#include "updater.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkReply>
#include <QRegularExpression>

Updater::Updater(const QString &repo, const QString &currentVersion, QObject *parent)
    : QObject(parent), m_repo(repo), m_current(currentVersion)
{
    m_timer.setInterval(24 * 60 * 60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &Updater::check);
    if (!configured()) m_state = "off";
}

void Updater::setChannel(int channel)
{
    m_channel = channel;
    if (!configured() || channel == 0) {
        m_timer.stop();
        setState("off");
        return;
    }
    if (m_state == "off") setState("idle");
    m_timer.start();
    QTimer::singleShot(8000, this, &Updater::check); // shortly after startup
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
    if (!configured() || m_channel == 0 || m_state == "checking") return;
    setState("checking");
    QNetworkRequest req(QUrl(QStringLiteral("https://api.github.com/repos/%1/releases?per_page=30").arg(m_repo)));
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
        if (best.isEmpty() || compareVersions(best, m_current) <= 0) {
            setState("upToDate");
            return;
        }
        m_latest = best.startsWith('v') ? best.mid(1) : best;
        m_url = bestObj.value("html_url").toString();
        m_notes = bestObj.value("body").toString().left(4000);
        m_beta = bestObj.value("prerelease").toBool();
        qInfo() << "Update available:" << m_latest << (m_beta ? "(beta)" : "");
        setState("available");
    });
}
