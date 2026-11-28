// SPDX-License-Identifier: MIT
#include "qmlsingletons.hpp"

#include "controller.hpp"
#include "platform.hpp"
#include "updater.hpp"

#include <QJSEngine>

namespace {
Controller *g_cam = nullptr;
Platform *g_platform = nullptr;
Updater *g_updater = nullptr;

template <typename T>
T *handOver(T *object)
{
    Q_ASSERT_X(object, "qmlsingletons", "set() must run before QML loads");
    // main() owns these; QML must never delete them.
    QJSEngine::setObjectOwnership(object, QJSEngine::CppOwnership);
    return object;
}
} // namespace

void qmlsingletons::set(Controller *cam, Platform *platform, Updater *updater)
{
    g_cam = cam;
    g_platform = platform;
    g_updater = updater;
}

Controller *Controller::create(QQmlEngine *, QJSEngine *)
{
    return handOver(g_cam);
}

Platform *Platform::create(QQmlEngine *, QJSEngine *)
{
    return handOver(g_platform);
}

Updater *Updater::create(QQmlEngine *, QJSEngine *)
{
    return handOver(g_updater);
}
