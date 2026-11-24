#include "logger.hpp"

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
constexpr size_t kKeepLines = 400;

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
    QFile::remove(path + ".1");
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

QString logDir() { return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/logs"; }
QString logFile() { return logDir() + "/gimbot.log"; }

void install()
{
    QDir().mkpath(logDir());
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

} // namespace Logger
