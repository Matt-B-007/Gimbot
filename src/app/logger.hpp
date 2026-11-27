// SPDX-License-Identifier: MIT
// Writes Qt's log messages to ~/.local/state/gimbot/gimbot.log (1 MB per
// file, 3 files kept) and keeps the latest ~500 lines in memory for reports.
#pragma once

#include <QString>
#include <QStringList>

namespace Logger {
void install();
void setVerbose(bool on); // include debug messages
QString logDir();         // ~/.local/state/gimbot (XDG_STATE_HOME)
QString stateDir();       // same folder; crash traces go in stateDir()/crashes
QString logFile();
QStringList recent(int lines = 200);
// The last lines of the log file (earlier sessions too), for `gimbot --report`.
QStringList fileTail(int lines = 200);
} // namespace Logger
