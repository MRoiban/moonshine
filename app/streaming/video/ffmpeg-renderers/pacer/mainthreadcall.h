#pragma once

#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// Main-thread work must be cancellable before the main thread joins rendering.
// Queued blocks own the gate, and never call into a destroyed renderer after stop().
class MainThreadCall
{
public:
    MainThreadCall() = default;
    ~MainThreadCall() { stop(); }
    MainThreadCall(const MainThreadCall&) = delete;
    MainThreadCall& operator=(const MainThreadCall&) = delete;

    bool run(std::function<void()> work)
    {
        auto state = m_State;
        if ([NSThread isMainThread]) {
            std::lock_guard<std::mutex> lock(state->mutex);
            if (state->stopped) return false;
            work();
            return true;
        }

        auto done = std::make_shared<bool>(false);
        dispatch_async(dispatch_get_main_queue(), ^{
            std::lock_guard<std::mutex> lock(state->mutex);
            if (!state->stopped) work();
            *done = true;
            state->cv.notify_all();
        });
        std::unique_lock<std::mutex> lock(state->mutex);
        state->cv.wait(lock, [&] { return *done || state->stopped; });
        return !state->stopped;
    }

    void stop()
    {
        std::lock_guard<std::mutex> lock(m_State->mutex);
        m_State->stopped = true;
        m_State->cv.notify_all();
    }

private:
    struct State {
        std::mutex mutex;
        std::condition_variable cv;
        bool stopped = false;
    };
    std::shared_ptr<State> m_State = std::make_shared<State>();
};
