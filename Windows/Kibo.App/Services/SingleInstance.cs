using System.Windows.Threading;

namespace Kibo.App.Services;

/// <summary>
/// One Kibo at a time. A second launch — a double-clicked shortcut while the first is in the
/// tray — signals the first to open its flyout, then exits, so the user never ends up with two
/// tray icons and two bubbles.
/// </summary>
internal sealed class SingleInstance : IDisposable
{
    private const string MutexName = @"Local\Kibo.SingleInstance";
    private const string SignalName = @"Local\Kibo.ShowFlyout";

    private readonly Mutex mutex;
    private readonly EventWaitHandle signal;
    private readonly RegisteredWaitHandle wait;

    private SingleInstance(Mutex mutex, EventWaitHandle signal, RegisteredWaitHandle wait)
    {
        this.mutex = mutex;
        this.signal = signal;
        this.wait = wait;
    }

    /// <summary>
    /// <c>null</c> when another instance already owns the session; the caller should exit. The
    /// callback runs on the calling thread's dispatcher each time a later launch signals.
    /// </summary>
    public static SingleInstance? TryAcquire(Action onSecondInstance)
    {
        var mutex = new Mutex(initiallyOwned: true, MutexName, out var createdNew);
        if (!createdNew)
        {
            try
            {
                EventWaitHandle.OpenExisting(SignalName).Set();
            }
            catch (WaitHandleCannotBeOpenedException)
            {
                // The first instance is still starting up; it will show itself anyway.
            }
            mutex.Dispose();
            return null;
        }

        var signal = new EventWaitHandle(initialState: false, EventResetMode.AutoReset, SignalName);
        var dispatcher = Dispatcher.CurrentDispatcher;
        var wait = ThreadPool.RegisterWaitForSingleObject(
            signal,
            (_, _) => dispatcher.BeginInvoke(onSecondInstance),
            state: null,
            millisecondsTimeOutInterval: -1,
            executeOnlyOnce: false);
        return new SingleInstance(mutex, signal, wait);
    }

    public void Dispose()
    {
        wait.Unregister(null);
        signal.Dispose();
        mutex.ReleaseMutex();
        mutex.Dispose();
    }
}
