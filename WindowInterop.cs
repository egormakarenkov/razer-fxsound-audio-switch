using System;
using System.Runtime.InteropServices;
using System.Text;

namespace RazerFx {
 public class WindowSnapshot {
  public IntPtr Handle;
  public bool Exists;
  public bool Visible;
  public bool Minimized;
 }
 public static class Windows {
  delegate bool EnumProc(IntPtr window, IntPtr parameter);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder text, int max);
  [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
  [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr window, int command);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
  public static WindowSnapshot Find(int processId) {
   IntPtr found=IntPtr.Zero;
   EnumWindows(delegate(IntPtr w, IntPtr p) {
    uint owner; GetWindowThreadProcessId(w,out owner);
    if(owner!=(uint)processId) return true;
    var text=new StringBuilder(512);GetWindowText(w,text,text.Capacity);
    if(text.ToString().IndexOf("7.1 Surround Sound",StringComparison.OrdinalIgnoreCase)<0) return true;
    found=w;return false;
   },IntPtr.Zero);
   return Read(found, processId);
  }
  public static WindowSnapshot Read(IntPtr window, int processId) {
   uint owner=0;
   bool exists=window!=IntPtr.Zero && IsWindow(window);
   if(exists) {GetWindowThreadProcessId(window,out owner);exists=owner==(uint)processId;}
   return new WindowSnapshot { Handle=window, Exists=exists, Visible=exists && IsWindowVisible(window), Minimized=exists && IsIconic(window) };
  }
  public static void Hide(IntPtr window) {ShowWindowAsync(window,0);}
  public static void RestoreWithoutActivation(IntPtr window) {ShowWindowAsync(window,4);}
 }
}
