// SPDX-License-Identifier: MIT
#include "logger.hpp"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QStandardPaths>

#include <atomic>
#include <cstdio>
#include <deque>

namespace {

constexpr qint64 kMaxBytes = 1024 * 1024;
constexpr size_t kKeepLines = 500;
constexpr int kKeepFiles = 3; // gimbot.log, gimbot.log.1, gimbot.log.2

QMutex g_mutex;
QFile *g_file = nullptr;
std::deque<QString> g_recent;
std::atomic<bool> g_verbose{false};

char levelChar(QtMsgType t)
{
    switch (t) {
    case QtDebugMsg: return 'D';
    case QtInfoMsg: return 'I';
    case QtWarningMsg: return 'W';
    case QtCriticalMsg: return 'E';
    case QtFatalMsg: return 'F';
    }
    return '?';
}

void rotateIfNeeded()
{
    if (!g_file || g_file->size() < kMaxBytes) return;
    const QString path = g_file->fileName();
    g_file->close();
    QFile::remove(path + "." + QString::number(kKeepFiles - 1));
    for (int i = kKeepFiles - 2; i >= 1; --i) QFile::rename(path + "." + QString::number(i), path + "." + QString::number(i + 1));
    QFile::rename(path, path + ".1");
    g_file->open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
}

void handler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    if (type == QtDebugMsg && !g_verbose) return;
    const QString line = QDateTime::currentDateTime().toString(Qt::ISODateWithMs) + ' ' + levelChar(type) + ' ' + msg;
    {
        QMutexLocker lock(&g_mutex);
        g_recent.push_back(line);
        while (g_recent.size() > kKeepLines) g_recent.pop_front();
        if (g_file && g_file->isOpen()) {
            g_file->write(line.toUtf8());
            g_file->write("\n");
            g_file->flush();
            rotateIfNeeded();
        }
    }
    std::fprintf(stderr, "%s\n", line.toLocal8Bit().constData());
    if (type == QtFatalMsg) std::abort();
}

} // namespace

namespace Logger {

QString stateDir()
{
    // XDG_STATE_HOME, falling back to ~/.local/state (Qt has no name for it before 6.7).
    QString base = qEnvironmentVariable("XDG_STATE_HOME");
    if (base.isEmpty() || !QDir::isAbsolutePath(base)) base = QDir::homePath() + "/.local/state";
    if (QStandardPaths::isTestModeEnabled()) base = QDir::homePath() + "/.qttest/state";
    return base + "/" + QCoreApplication::organizationName();
}
QString logDir() { return stateDir(); }
QString logFile() { return logDir() + "/gimbot.log"; }

void install()
{
    QDir().mkpath(logDir());
    // Logs used to live in ~/.local/share/gimbot/logs; move them over once.
    const QString old = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/" +
                        QCoreApplication::organizationName() + "/logs";
    if (QDir(old).exists()) {
        for (const QString &f : QDir(old).entryList(QDir::Files))
            if (!QFile::exists(logDir() + "/" + f)) QFile::rename(old + "/" + f, logDir() + "/" + f);
        QDir(old).removeRecursively();
    }
    g_file = new QFile(logFile());
    g_file->open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    qInstallMessageHandler(handler);
}

void setVerbose(bool on) { g_verbose = on; }

QStringList recent(int lines)
{
    QMutexLocker lock(&g_mutex);
    QStringList out;
    const int start = std::max(0, int(g_recent.size()) - lines);
    for (int i = start; i < int(g_recent.size()); ++i) out << g_recent[i];
    return out;
}

QStringList fileTail(int lines)
{
    QStringList all;
    // The previous file first, in case the current one was just started.
    for (const QString &path : {logFile() + QStringLiteral(".1"), logFile()}) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        f.seek(std::max<qint64>(0, f.size() - 256 * 1024)); // the end is enough
        all += QString::fromUtf8(f.readAll()).split('\n', Qt::SkipEmptyParts);
    }
    return all.mid(std::max<qsizetype>(0, all.size() - lines));
}

} // namespace Logger
