#include "worker.hpp"

#include <QMetaObject>

Worker::Worker(QObject *parent) : QObject(parent), m_ctx(new QObject)
{
    m_thread.setObjectName(QStringLiteral("gimbot-sdk"));
    m_ctx->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_ctx, &QObject::deleteLater);
    m_thread.start();
}

Worker::~Worker() { stop(); }

void Worker::stop()
{
    // Runs the jobs already queued, then ends the thread.
    m_thread.quit();
    m_thread.wait();
}

void Worker::post(std::function<void()> job)
{
    QMetaObject::invokeMethod(m_ctx, std::move(job), Qt::QueuedConnection);
}

void Worker::postLatest(const QString &key, std::function<void()> job)
{
    {
        QMutexLocker lock(&m_mutex);
        const bool queued = m_latest.contains(key);
        m_latest.insert(key, std::move(job));
        if (queued) return;
    }
    post([this, key] {
        std::function<void()> fn;
        {
            QMutexLocker lock(&m_mutex);
            fn = m_latest.take(key);
        }
        if (fn) fn();
    });
}
