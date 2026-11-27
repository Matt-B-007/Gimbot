// SPDX-License-Identifier: MIT
#include "trayicon.hpp"

#include <QCoreApplication>
#include <QPainter>
#include <QPainterPath>

namespace trayicon {

State stateFor(const Inputs &in)
{
    if (in.problem) return State::Problem;
    if (!in.connected) return State::Disconnected;
    if (in.muted) return State::Muted;
    if (in.updateReady) return State::Attention;
    if (in.tracking) return State::Active;
    return State::Idle;
}

QString name(State s)
{
    switch (s) {
    case State::Idle: return QStringLiteral("idle");
    case State::Active: return QStringLiteral("active");
    case State::Muted: return QStringLiteral("muted");
    case State::Attention: return QStringLiteral("attention");
    case State::Problem: return QStringLiteral("problem");
    case State::Disconnected: return QStringLiteral("disconnected");
    }
    return {};
}

QString tooltip(State s)
{
    auto tr = [](const char *t) { return QCoreApplication::translate("TrayIcon", t); };
    switch (s) {
    case State::Idle: return tr("Camera connected");
    case State::Active: return tr("Tracking on");
    case State::Muted: return tr("Camera asleep or tracking paused");
    case State::Attention: return tr("An update is ready");
    case State::Problem: return tr("The camera reported a problem");
    case State::Disconnected: return tr("No camera connected");
    }
    return {};
}

QImage render(State s, const QColor &plain, int size)
{
    // Breeze's own colors, so the dots match the rest of the panel.
    const QColor red(0xda, 0x44, 0x53);
    const QColor amber(0xf6, 0x74, 0x00);
    const bool darkPanel = plain.lightnessF() > 0.5; // light text means a dark panel
    const QColor accent = darkPanel ? QColor(0xc0, 0x84, 0xfc) : QColor(0x7e, 0x22, 0xce); // Gimbot purple

    QColor ink = plain;
    if (s == State::Active) ink = accent;
    if (s == State::Disconnected) ink.setAlphaF(0.45);

    QImage img(size, size, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    p.scale(size / 100.0, size / 100.0);

    // The Gimbot mark: an open ring ending in a bar, and a centre dot.
    QPainterPath ring;
    ring.moveTo(69.8, 30.2);
    ring.arcTo(22, 22, 56, 56, 45, 315);
    ring.lineTo(66, 50);
    p.setPen(QPen(ink, 13, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p.setBrush(Qt::NoBrush);
    p.drawPath(ring);
    p.setPen(Qt::NoPen);
    p.setBrush(ink);
    p.drawEllipse(QPointF(50, 50), 10, 10);

    // Badges sit on a cut-out so they read on any panel color.
    auto badge = [&](const QPointF &c, double r, const QColor &fill) {
        p.setCompositionMode(QPainter::CompositionMode_Clear);
        p.drawEllipse(c, r + 7, r + 7);
        p.setCompositionMode(QPainter::CompositionMode_SourceOver);
        p.setBrush(fill);
        p.drawEllipse(c, r, r);
    };
    if (s == State::Muted) {
        badge({74, 74}, 22, red);
        p.setPen(QPen(Qt::white, 8, Qt::SolidLine, Qt::RoundCap));
        p.drawLine(QPointF(63, 74), QPointF(85, 74));
    } else if (s == State::Attention) {
        badge({80, 20}, 16, amber);
    } else if (s == State::Problem) {
        badge({80, 20}, 16, red);
    }
    return img;
}

} // namespace trayicon
