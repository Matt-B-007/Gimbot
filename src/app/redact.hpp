#pragma once

#include <QList>
#include <QPair>
#include <QString>

// Takes personal details out of a report before it leaves the computer. The
// base set is shared with the other apps in the family:
//   ~          the home folder (also Windows-style, e.g. Z:\home\matt\…)
//   <user>     the user name
//   <host>     the computer's name
//   <ip>       IPv4 and IPv6 addresses (version numbers like 0.11.0.1 stay)
//   <mac>      network hardware addresses
//   <secret>   tokens, passwords and keys
//   <steamid>  Steam account ids (17 digits from 7656119; game ids stay)
// Apps add their own, e.g. Gimbot's <serial>.
namespace redact {

struct Context {
    QString home;
    QString user;
    QString host;
    QList<QPair<QString, QString>> extra; // exact text -> placeholder
};

QString apply(QString text, const Context &ctx);

} // namespace redact
