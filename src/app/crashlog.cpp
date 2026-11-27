#include "crashlog.hpp"

#include "logger.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <csignal>
#include <cstring>
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>

#ifdef GIMBOT_HAVE_KF6
#include <KCrash>
#endif

namespace {

constexpr int kKeep = 10;
char g_path[4096] = {0};   // this session's crash file, prepared up front
char g_header[256] = {0};

// Runs inside a signal handler: only async-signal-safe calls.
void writeTrace(int sig)
{
    if (!g_path[0]) return;
    const int fd = ::open(g_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (fd < 0) return;
    auto put = [fd](const char *s) { [[maybe_unused]] auto n = ::write(fd, s, std::strlen(s)); };
    put(g_header);
    put("Signal: ");
    char num[16];
    int v = sig, i = 15;
    num[i] = 0;
    do { num[--i] = char('0' + v % 10); v /= 10; } while (v && i > 0);
    put(num + i);
    put("\nBacktrace:\n");
    void *frames[64];
    const int n = ::backtrace(frames, 64);
    ::backtrace_symbols_fd(frames, n, fd);
    ::close(fd);
}

#ifndef GIMBOT_HAVE_KF6
void onFault(int sig)
{
    writeTrace(sig);
    std::signal(sig, SIG_DFL); // then crash as usual (core dump, exit status)
    ::raise(sig);
}
#endif

} // namespace

namespace CrashLog {

QString dir() { return Logger::stateDir() + "/crashes"; }

void install()
{
    QDir().mkpath(dir());
    // Keep the newest kKeep traces.
    QFileInfoList list = QDir(dir()).entryInfoList({"crash-*.txt"}, QDir::Files, QDir::Name);
    while (list.size() >= kKeep) QFile::remove(list.takeFirst().absoluteFilePath());
    const QByteArray path =
        (dir() + "/crash-" + QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss") + ".txt").toLocal8Bit();
    std::strncpy(g_path, path.constData(), sizeof(g_path) - 1);
    const QByteArray header = QByteArray("Gimbot ") + GIMBOT_VERSION + " crashed at " +
                              QDateTime::currentDateTime().toString(Qt::ISODate).toUtf8() + " (session start)\n";
    std::strncpy(g_header, header.constData(), sizeof(g_header) - 1);
    // Backtraces need libgcc loaded before a crash, not during one.
    void *warm[1];
    ::backtrace(warm, 1);
#ifdef GIMBOT_HAVE_KF6
    KCrash::setEmergencySaveFunction(writeTrace);
#else
    for (int sig : {SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGABRT}) std::signal(sig, onFault);
#endif
}

QString latest()
{
    const QFileInfoList list = QDir(dir()).entryInfoList({"crash-*.txt"}, QDir::Files, QDir::Name);
    for (int i = list.size() - 1; i >= 0; --i) {
        if (QString::fromLocal8Bit(g_path) == list[i].absoluteFilePath()) continue; // this session
        QFile f(list[i].absoluteFilePath());
        if (f.open(QIODevice::ReadOnly)) return QString::fromUtf8(f.read(16 * 1024));
    }
    return {};
}

} // namespace CrashLog
