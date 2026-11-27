#include "settingsstore.hpp"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>

namespace settingsstore {

static const char kVersionKey[] = "meta/settingsVersion";

Result migrate(QSettings &s)
{
    Result r;
    s.sync();
    const bool hadAnything = !s.allKeys().isEmpty();
    r.from = s.value(kVersionKey, hadAnything ? 1 : 0).toInt();
    r.newInstall = !hadAnything;
    if (r.from > kCurrentVersion) {
        r.newer = true;
        qWarning() << "Settings were written by a newer Gimbot (version" << r.from << "); keeping them as they are";
        return r;
    }
    if (r.from == 1) {
        s.setValue("settings/tourDone", true);
        s.remove("settings/previewQuality");
    }
    if (r.from != kCurrentVersion) {
        s.setValue(kVersionKey, kCurrentVersion);
        s.sync();
        if (!r.newInstall) qInfo() << "Settings updated from version" << r.from << "to" << kCurrentVersion;
    }
    return r;
}

bool backup(const QString &file, const QString &backupDir, qint64 minIntervalSecs, int keep)
{
    if (!QFileInfo::exists(file)) return false;
    QDir dir(backupDir);
    if (!dir.exists() && !QDir().mkpath(backupDir)) return false;
    const QStringList filters = {QStringLiteral("settings-*.conf")};
    QFileInfoList list = dir.entryInfoList(filters, QDir::Files, QDir::Name); // names sort by time
    if (!list.isEmpty() && list.last().lastModified().secsTo(QDateTime::currentDateTime()) < minIntervalSecs)
        return false;
    QFile in(file);
    if (!in.open(QIODevice::ReadOnly)) return false;
    const QByteArray data = in.readAll();
    const QString name = QStringLiteral("settings-%1.conf").arg(QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss-zzz"));
    QSaveFile out(dir.filePath(name)); // temporary file, then rename
    if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.commit()) return false;
    list = dir.entryInfoList(filters, QDir::Files, QDir::Name);
    while (list.size() > keep) QFile::remove(list.takeFirst().absoluteFilePath());
    return true;
}

} // namespace settingsstore
