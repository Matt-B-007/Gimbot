// SPDX-License-Identifier: MIT
// Crash traces: when Gimbot crashes, a short file with the signal and a
// backtrace is written to ~/.local/state/gimbot/crashes (the last 10 kept).
// The "running" marker (Platform) tells the next start that it happened;
// these files add the details to the bug report.
#pragma once

#include <QString>

namespace CrashLog {
// Prepare the file for this session and install the fault handler. With
// KDE Frameworks, KCrash keeps its own handler and calls ours first.
void install();
// The newest crash trace from an earlier session, or empty.
QString latest();
// For the self-test: where traces go.
QString dir();
} // namespace CrashLog
