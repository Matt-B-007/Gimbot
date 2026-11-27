// SPDX-License-Identifier: MIT
#include "redact.hpp"

#include <QRegularExpression>

namespace redact {

namespace {

using RE = QRegularExpression;

// An IPv4 address that isn't a version number. Version numbers show up as
// "v1.2.3.4", "==0.11.0.1", "Qt 6.8.1.0", "1.2.3.4-beta", so anything with
// those around it, or starting with 0 (not a usable address), stays.
bool looksLikeVersion(const QString &text, qsizetype start, qsizetype end, const QString &match)
{
    if (match.startsWith(QLatin1String("0."))) return true;
    const QString before = text.mid(std::max<qsizetype>(0, start - 9), std::min<qsizetype>(start, 9)).toLower();
    static const RE versionBefore(QStringLiteral("(v|==|>=|<=|~=|version |version: |ver )$"));
    if (versionBefore.match(before).hasMatch()) return true;
    if (end < text.size()) {
        const QChar next = text.at(end);
        if (next == '-' || next == '+' || next == '_' || next.isLetter()) return true;
    }
    return false;
}

QString replaceIPv4(const QString &text)
{
    static const RE ipv4(QStringLiteral("(?<![\\w.])((?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(?:\\.(?:25[0-5]|2[0-4]\\d|"
                                        "1\\d\\d|[1-9]?\\d)){3})(?![\\w.]*\\d)(?!\\.\\w)"));
    QString out;
    qsizetype last = 0;
    auto it = ipv4.globalMatch(text);
    while (it.hasNext()) {
        const auto m = it.next();
        const qsizetype s = m.capturedStart(1), e = m.capturedEnd(1);
        if (looksLikeVersion(text, s, e, m.captured(1))) continue;
        out += text.mid(last, s - last);
        out += QStringLiteral("<ip>");
        last = e;
    }
    out += text.mid(last);
    return out;
}

// IPv6: hex groups with colons. To leave clock times (21:33:05) and
// "key: value" text alone it needs "::" or a hex letter, and at least two colons.
bool isIPv6(const QString &t)
{
    QString addr = t.section('%', 0, 0); // zone, e.g. %wlan0
    if (addr.count(':') < 2) return false;
    const bool compressed = addr.contains(QLatin1String("::"));
    if (addr.count(QLatin1String("::")) > 1) return false;
    if (!compressed && !addr.contains(QRegularExpression(QStringLiteral("[A-Fa-f]")))) return false;
    const QStringList groups = addr.split(':');
    if (groups.size() > 8 || (!compressed && groups.size() != 8)) return false;
    static const RE group(QStringLiteral("^[0-9A-Fa-f]{0,4}$"));
    for (const QString &g : groups)
        if (!group.match(g).hasMatch()) return false;
    return true;
}

QString replaceIPv6(const QString &text)
{
    static const RE candidate(QStringLiteral("(?<![\\w:.])[0-9A-Fa-f:]*:[0-9A-Fa-f:]*(?:%\\w+)?(?![\\w:])"));
    QString out;
    qsizetype last = 0;
    auto it = candidate.globalMatch(text);
    while (it.hasNext()) {
        const auto m = it.next();
        if (!isIPv6(m.captured(0))) continue;
        out += text.mid(last, m.capturedStart(0) - last);
        out += QStringLiteral("<ip>");
        last = m.capturedEnd(0);
    }
    out += text.mid(last);
    return out;
}

} // namespace

QString apply(QString text, const Context &ctx)
{
    // App-specific details first: they're exact strings, like a serial number.
    for (const auto &e : ctx.extra)
        if (e.first.size() > 3) text.replace(e.first, e.second);

    // Secrets before anything else rewrites them.
    static const RE keyValue(
        QStringLiteral(
            "((?:password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|auth|authorization|private[_-]?key)"
            "[\"']?\\s*[:=]\\s*[\"']?)(?:Bearer\\s+|Basic\\s+)?[^\\s\"',;&]+"),
        RE::CaseInsensitiveOption);
    text.replace(keyValue, QStringLiteral("\\1<secret>"));
    static const RE bearer(QStringLiteral("\\b(Bearer|Basic)\\s+[A-Za-z0-9._~+/=-]{8,}"));
    text.replace(bearer, QStringLiteral("\\1 <secret>"));
    static const RE knownTokens(
        QStringLiteral("\\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|"
                       "xox[abprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})"));
    text.replace(knownTokens, QStringLiteral("<secret>"));
    static const RE urlPassword(QStringLiteral("(\\w+://[^\\s:/@]+:)[^\\s@/]+@"));
    text.replace(urlPassword, QStringLiteral("\\1<secret>@"));

    // Home folder, Linux and Windows-style (Wine/Proton paths like Z:\home\matt).
    if (ctx.home.size() > 1) {
        text.replace(ctx.home, QStringLiteral("~"));
        QString win = ctx.home;
        win.replace('/', QLatin1String("\\\\"));
        text.replace(
            RE(QStringLiteral("\\b[A-Za-z]:") + win + QStringLiteral("(?=\\\\|\\b|$)"), RE::CaseInsensitiveOption),
            QStringLiteral("~"));
    }
    if (ctx.user.size() > 2) {
        const QString u = RE::escape(ctx.user);
        // Windows profiles: C:\users\matt
        text.replace(
            RE(QStringLiteral("\\b[A-Za-z]:\\\\users\\\\") + u + QStringLiteral("\\b"), RE::CaseInsensitiveOption),
            QStringLiteral("~"));
        text.replace(RE(QStringLiteral("\\b") + u + QStringLiteral("\\b")), QStringLiteral("<user>"));
    }
    if (ctx.host.size() > 2)
        text.replace(
            RE(QStringLiteral("\\b") + RE::escape(ctx.host) + QStringLiteral("\\b"), RE::CaseInsensitiveOption),
            QStringLiteral("<host>"));

    // Steam account ids only; game and app ids are short and stay.
    static const RE steam(QStringLiteral("\\b7656119\\d{10}\\b"));
    text.replace(steam, QStringLiteral("<steamid>"));

    // MAC before IPv6: both use colons.
    static const RE mac(QStringLiteral("\\b[0-9A-Fa-f]{2}(?:([:-])[0-9A-Fa-f]{2})(?:\\1[0-9A-Fa-f]{2}){4}\\b"));
    text.replace(mac, QStringLiteral("<mac>"));
    text = replaceIPv6(text);
    text = replaceIPv4(text);
    return text;
}

} // namespace redact
