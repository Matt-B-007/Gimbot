// SPDX-License-Identifier: MIT
#pragma once

#include <QColor>
#include <QImage>
#include <QString>

// The tray icon's states, shared with the other apps in the family (Sluice's
// tray is the reference):
//   Idle          plain icon             camera connected, nothing going on
//   Active        lit in the accent      tracking is on
//   Muted         red badge              asleep or tracking paused, on purpose
//   Attention     amber dot              an update is ready
//   Problem       red dot                the camera just reported an error
//   Disconnected  grey                   no camera
namespace trayicon {

enum class State { Idle, Active, Muted, Attention, Problem, Disconnected };

struct Inputs {
    bool connected = false;
    bool problem = false;
    bool muted = false;
    bool updateReady = false;
    bool tracking = false;
};

// Most important first: a problem, then no camera, then what the user chose.
State stateFor(const Inputs &in);
QString name(State s);    // "idle", "active", ... (logs, tests)
QString tooltip(State s); // shown under "Gimbot"

// Draws the icon at `size` pixels. `plain` is the panel's text color; the
// accent is chosen for a light or dark panel from it.
QImage render(State s, const QColor &plain, int size);

} // namespace trayicon
