// SPDX-License-Identifier: MIT
// gimbot --self-test [--quick]
//
// --quick: can the program start, load its interface and read the settings?
//          A few seconds, no network, no camera, no other programs. Run on a
//          new build before it replaces the installed one.
// full:    adds the simulated camera, a settings save/read/migrate/backup
//          round trip, the log and crash folders, and the OBSBOT library.
//
// Prints one line per check and exits 0 if everything passed. Runs with an
// off-screen display and temporary folders, so it never touches the user's
// settings or windows, and it ignores an already-running Gimbot.
#pragma once

namespace selftest {
// True if argv asks for the self-test.
bool requested(int argc, char *argv[]);
int run(int argc, char *argv[]);
} // namespace selftest
