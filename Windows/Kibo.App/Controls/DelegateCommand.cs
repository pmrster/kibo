using System.Windows.Input;

namespace Kibo.App.Controls;

/// <summary>The usual tiny <see cref="ICommand"/>, so views can bind buttons to model methods.</summary>
internal sealed class DelegateCommand(Action execute, Func<bool>? canExecute = null) : ICommand
{
    public event EventHandler? CanExecuteChanged;

    public bool CanExecute(object? parameter) => canExecute?.Invoke() ?? true;

    public void Execute(object? parameter) => execute();

    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
