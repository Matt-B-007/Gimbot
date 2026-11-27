// SPDX-License-Identifier: MIT
// Tests for the parts of the desktop app that need Qt GUI: the theme's
// contrast, the tray icon states and report redaction.
#include "redact.hpp"
#include "trayicon.hpp"

#include <QFile>
#include <QGuiApplication>
#include <QMetaProperty>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QtTest>

#include <cmath>

namespace {

double luminance(const QColor &c)
{
    auto ch = [](double v) { return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * ch(c.redF()) + 0.7152 * ch(c.greenF()) + 0.0722 * ch(c.blueF());
}

double contrast(const QColor &a, const QColor &b)
{
    const double la = luminance(a), lb = luminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

} // namespace

class UiTest : public QObject
{
    Q_OBJECT

private slots:
    // House standard v1.3: every text color on every surface (bg, sidebar,
    // card, control, hover), in the light and the dark theme, passes WCAG AA
    // (4.5:1), and so does the text on filled accent buttons (dark ink in the
    // dark theme, white in the light one). Gimbot's accent is purple.
    void themeContrast()
    {
        QFile f(QStringLiteral(GIMBOT_SOURCE_DIR "/qml/Theme.qml"));
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray qml = f.readAll();
        qml.replace("pragma Singleton", ""); // load it as a plain object
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(qml, QUrl::fromLocalFile(QStringLiteral(GIMBOT_SOURCE_DIR "/qml/Theme.qml")));
        QScopedPointer<QObject> theme(component.create());
        QVERIFY2(theme, qPrintable(component.errorString()));

        const char *texts[] = {"text", "textMuted", "textFaint", "accentText", "danger", "success", "warning", "brand"};
        const char *backgrounds[] = {"bg", "sidebar", "surface", "surface2", "hover", "sunken"};
        for (int mode : {1, 2}) { // dark, light
            theme->setProperty("mode", mode);
            theme->setProperty("useSystemAccent", false);
            const QString name = mode == 1 ? QStringLiteral("dark") : QStringLiteral("light");
            QCOMPARE(theme->property("brand").value<QColor>(), QColor(mode == 1 ? "#c084fc" : "#7e22ce"));
            QCOMPARE(theme->property("accentInk").value<QColor>(), QColor(mode == 1 ? "#0c1016" : "#ffffff"));
            QCOMPARE(theme->property("bg").value<QColor>(), QColor(mode == 1 ? "#0c1016" : "#f5f7fa"));
            // The standard's own minimums on its worst surface.
            for (const char *bg : backgrounds) {
                const QColor b = theme->property(bg).value<QColor>();
                QVERIFY2(contrast(theme->property("text").value<QColor>(), b) >= 12.3, bg);
                QVERIFY2(contrast(theme->property("textMuted").value<QColor>(), b) >= 5.0, bg);
            }
            for (const char *fg : texts) {
                for (const char *bg : backgrounds) {
                    const QColor a = theme->property(fg).value<QColor>();
                    const QColor b = theme->property(bg).value<QColor>();
                    QVERIFY(a.isValid() && b.isValid());
                    const double r = contrast(a, b);
                    QVERIFY2(r >= 4.5, qPrintable(QStringLiteral("%1 theme: %2 %3 on %4 %5 is %6:1")
                                                      .arg(name, fg, a.name(), bg, b.name())
                                                      .arg(r, 0, 'f', 2)));
                }
            }
            // Text on filled accent buttons: 7.2:1 for dark ink, 5.1:1 for white.
            const double ink =
                contrast(theme->property("accentInk").value<QColor>(), theme->property("accent").value<QColor>());
            QVERIFY2(ink >= (mode == 1 ? 7.2 : 5.1),
                     qPrintable(
                         QStringLiteral("%1 theme: button text on the accent is %2:1").arg(name).arg(ink, 0, 'f', 2)));
        }
    }

    void trayStates()
    {
        using trayicon::State;
        trayicon::Inputs in;
        QCOMPARE(trayicon::stateFor(in), State::Disconnected);
        in.connected = true;
        QCOMPARE(trayicon::stateFor(in), State::Idle);
        in.tracking = true;
        QCOMPARE(trayicon::stateFor(in), State::Active);
        in.updateReady = true;
        QCOMPARE(trayicon::stateFor(in), State::Attention);
        in.muted = true;
        QCOMPARE(trayicon::stateFor(in), State::Muted);
        in.connected = false;
        QCOMPARE(trayicon::stateFor(in), State::Disconnected);
        in.problem = true;
        QCOMPARE(trayicon::stateFor(in), State::Problem);

        // Each state draws something, and they all look different.
        QSet<QByteArray> seen;
        for (auto s :
             {State::Idle, State::Active, State::Muted, State::Attention, State::Problem, State::Disconnected}) {
            for (const QColor &panel : {QColor("#232629"), QColor("#fcfcfc")}) {
                const QImage img = trayicon::render(s, panel, 22);
                QCOMPARE(img.size(), QSize(22, 22));
                QVERIFY(!trayicon::tooltip(s).isEmpty());
                const QByteArray bytes(reinterpret_cast<const char *>(img.constBits()), img.sizeInBytes());
                QVERIFY2(!seen.contains(bytes), qPrintable(trayicon::name(s)));
                seen.insert(bytes);
                const QString out = qEnvironmentVariable("GIMBOT_TRAY_SHOTS");
                if (!out.isEmpty())
                    trayicon::render(s, panel, 64)
                        .save(QStringLiteral("%1/tray-%2-%3.png")
                                  .arg(out, trayicon::name(s), panel.lightness() > 128 ? "dark" : "light"));
            }
        }
    }

    void redaction_data()
    {
        QTest::addColumn<QString>("in");
        QTest::addColumn<QString>("out");
        QTest::newRow("home") << "Log: /home/matt/.local/state/gimbot/gimbot.log"
                              << "Log: ~/.local/state/gimbot/gimbot.log";
        QTest::newRow("windows home") << R"(Z:\home\matt\Games\x.exe)" << R"(~\Games\x.exe)";
        QTest::newRow("windows profile") << R"(C:\users\matt\AppData)" << R"(~\AppData)";
        QTest::newRow("user") << "user matt logged in" << "user <user> logged in";
        QTest::newRow("user inside a word stays") << "mattress" << "mattress";
        QTest::newRow("host") << "Hostname: cachy-desk" << "Hostname: <host>";
        QTest::newRow("ipv4") << "connect to 192.168.1.20:8080 failed" << "connect to <ip>:8080 failed";
        QTest::newRow("ipv6") << "resolved to 2606:4700:4700::1111" << "resolved to <ip>";
        QTest::newRow("ipv6 link-local") << "fe80::1c2b:3aff:fe4d%wlan0 up" << "<ip> up";
        QTest::newRow("mac") << "usb0 at 3c:22:fb:01:ab:9e" << "usb0 at <mac>";
        QTest::newRow("token") << "token=ghp_abcdefghijklmnopqrstuvwxyz0123" << "token=<secret>";
        QTest::newRow("bare github token") << "using ghp_abcdefghijklmnopqrstuvwxyz0123 now" << "using <secret> now";
        QTest::newRow("password") << R"("password": "hunter22")" << R"("password": "<secret>")";
        QTest::newRow("bearer") << "Authorization: Bearer abc.def.ghi123" << "Authorization: <secret>";
        // (split so the web address check doesn't read "bob" as a host)
        QTest::newRow("url password") << QStringLiteral("https:") + "//bob:pa55@example.invalid/x"
                                      << QStringLiteral("https:") + "//bob:<secret>@example.invalid/x";
        QTest::newRow("steam account") << "steamid 76561198012345678" << "steamid <steamid>";
        QTest::newRow("steam game id stays") << "appid 1245620" << "appid 1245620";
        QTest::newRow("serial") << "serial RMOWGHM1234" << "serial <serial>";
        // Version numbers aren't addresses or secrets.
        QTest::newRow("pip pin") << "shellcheck-py==0.11.0.1" << "shellcheck-py==0.11.0.1";
        QTest::newRow("four-part version") << "version 0.11.0.1" << "version 0.11.0.1";
        QTest::newRow("v prefix") << "Gimbot v1.2.3.4 started" << "Gimbot v1.2.3.4 started";
        QTest::newRow("version with suffix") << "kernel 6.17.8.2-cachyos" << "kernel 6.17.8.2-cachyos";
        QTest::newRow("app version") << "Gimbot 0.1.0-beta.11 (Qt 6.8.1)" << "Gimbot 0.1.0-beta.11 (Qt 6.8.1)";
        QTest::newRow("library") << "libdev.so.1.0.3" << "libdev.so.1.0.3";
        QTest::newRow("clock") << "21:33:05.123 I Camera ready" << "21:33:05.123 I Camera ready";
        QTest::newRow("public key stays") << "key RWQcs3jtP2jTiAMafwQX8UwciSjOH4o9tQcCVvYl2NkdnOeVupKPlhvC"
                                          << "key RWQcs3jtP2jTiAMafwQX8UwciSjOH4o9tQcCVvYl2NkdnOeVupKPlhvC";
    }

    void redaction()
    {
        QFETCH(QString, in);
        QFETCH(QString, out);
        redact::Context ctx;
        ctx.home = QStringLiteral("/home/matt");
        ctx.user = QStringLiteral("matt");
        ctx.host = QStringLiteral("cachy-desk");
        ctx.extra.append({QStringLiteral("RMOWGHM1234"), QStringLiteral("<serial>")});
        QCOMPARE(redact::apply(in, ctx), out);
    }
};

QTEST_MAIN(UiTest)
#include "test_ui.moc"
