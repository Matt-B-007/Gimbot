// Settings file housekeeping: a version number with migrations, and rolling
// backups. Qt writes the file itself with a temporary file and a rename.
#pragma once

#include <QSettings>
#include <QString>

namespace settingsstore {

// Bump when stored settings change shape, and add a step to migrate().
constexpr int kCurrentVersion = 3;

struct Result {
    int from = 0;          // version found (0 = before versions existed)
    bool newInstall = false;
    bool newer = false;    // written by a newer Gimbot (e.g. after Go back)
};

// Bring the settings up to kCurrentVersion.
//  1 → 2: existing installs have seen the app, so the tour doesn't start by
//         itself after this update; the old preview quality setting is gone.
Result migrate(QSettings &s);

// Copy the settings file into backupDir if the newest backup is older than
// minIntervalSecs, keeping the newest `keep`. Returns true if one was made.
bool backup(const QString &file, const QString &backupDir, qint64 minIntervalSecs = 15 * 60, int keep = 5);

} // namespace settingsstore
