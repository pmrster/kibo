global using Kibo.Core;
// UseWPF and UseWindowsForms both define Application, Clipboard and MessageBox. WinForms is
// reached through this alias only; a file-scope `using System.Windows.Forms;` is never written
// (its implicit usings are removed in the csproj for the same reason).
global using Forms = System.Windows.Forms;
// The WPF namespaces nearly every control and window file needs, so they are not repeated.
global using System.Windows;
global using System.Windows.Automation;
global using System.Windows.Controls;
global using System.Windows.Media;
