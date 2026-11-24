// Runs SDK calls one at a time on a background thread. The SDK blocks
// until the camera replies, so nothing here may run on the GUI thread.
#pragma once

#include <QHash>
#include <QMutex>
#include <QObject>
#include <QThread>

#include <functional>

class Worker : public QObject {
    Q_OBJECT
public:
    explicit Worker(QObject *parent = nullptr);
    ~Worker() override;

    // Queue a job.
    void post(std::function<void()> job);

    // Queue a job under a key; if a job with the same key is still waiting,
    // it is replaced. Used for sliders so only the latest value is sent.
    void postLatest(const QString &key, std::function<void()> job);

private:
    QThread m_thread;
    QObject *m_ctx;
    QMutex m_mutex;
    QHash<QString, std::function<void()>> m_latest;
};
