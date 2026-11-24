// Writes Qt's log messages to ~/.local/share/gimbot/logs/gimbot.log
// (rotated at 1 MB) and keeps the latest lines in memory for bug reports.
#pragma once

#include <QString>
#include <QStringList>

namespace Logger {
void install();
void setVerbose(bool on); // include debug messages
QString logDir();
QString logFile();
QStringList recent(int lines = 200);
} // namespace Logger
