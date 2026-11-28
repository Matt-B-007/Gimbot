// SPDX-License-Identifier: MIT
#pragma once

class Controller;
class Platform;
class Updater;

// The app makes one Controller, Platform and Updater in main(); QML reaches
// them as the singletons Cam, Platform and Updater. Call set() before the
// QML engine loads anything.
namespace qmlsingletons {
void set(Controller *cam, Platform *platform, Updater *updater);
}
