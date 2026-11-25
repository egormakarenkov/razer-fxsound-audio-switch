using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace RazerFx {
 [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMEnumerator {}
 [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IMMDeviceEnumerator {
  [PreserveSig] int EnumAudioEndpoints(int flow, uint state, out IMMDeviceCollection devices);
  [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
  [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
  [PreserveSig] int RegisterEndpointNotificationCallback(IntPtr client);
  [PreserveSig] int UnregisterEndpointNotificationCallback(IntPtr client);
 }
 [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IMMDeviceCollection {
  [PreserveSig] int GetCount(out uint count);
  [PreserveSig] int Item(uint index, out IMMDevice device);
 }
 [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IMMDevice {
  [PreserveSig] int Activate(ref Guid iid, uint context, IntPtr parameters, out IntPtr result);
  [PreserveSig] int OpenPropertyStore(uint access, out IPropertyStore properties);
  [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
  [PreserveSig] int GetState(out uint state);
 }
 [StructLayout(LayoutKind.Sequential)] struct PropertyKey { public Guid fmtid; public uint pid; }
 [StructLayout(LayoutKind.Explicit, Size=24)] struct PropVariant {
  [FieldOffset(0)] public ushort vt;
  [FieldOffset(8)] public IntPtr ptr;
 }
 [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IPropertyStore {
  [PreserveSig] int GetCount(out uint count);
  [PreserveSig] int GetAt(uint index, out PropertyKey key);
  [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
  [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
  [PreserveSig] int Commit();
 }
 [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] class PolicyClient {}
 [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IPolicyConfig {
  void GetMixFormat(); void GetDeviceFormat(); void ResetDeviceFormat(); void SetDeviceFormat();
  void GetProcessingPeriod(); void SetProcessingPeriod(); void GetShareMode(); void SetShareMode();
  void GetPropertyValue(); void SetPropertyValue();
  [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
  void SetEndpointVisibility();
 }
 public class Endpoint { public string Id; public string Name; public uint State; }
 public static class Audio {
  [DllImport("ole32.dll")] static extern int PropVariantClear(ref PropVariant value);
  static void Check(int hr) { Marshal.ThrowExceptionForHR(hr); }
  static void Release(object o) { if(o != null && Marshal.IsComObject(o)) Marshal.ReleaseComObject(o); }
  public static Endpoint[] List() {
   var e=(IMMDeviceEnumerator)new MMEnumerator(); IMMDeviceCollection c=null;
   var result=new List<Endpoint>();
   try { Check(e.EnumAudioEndpoints(0,1,out c)); uint count; Check(c.GetCount(out count));
    for(uint i=0;i<count;i++) { IMMDevice d=null; IPropertyStore p=null;
     try { Check(c.Item(i,out d)); string id; uint state; Check(d.GetId(out id)); Check(d.GetState(out state));
      Check(d.OpenPropertyStore(0,out p)); var key=new PropertyKey { fmtid=new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"),pid=14 };
      PropVariant value; Check(p.GetValue(ref key,out value)); string name;
      try { name=value.vt==31 ? Marshal.PtrToStringUni(value.ptr) : ""; } finally {PropVariantClear(ref value);}
      result.Add(new Endpoint {Id=id,Name=name,State=state});
     } finally {Release(p);Release(d);}
    }
   } finally {Release(c);Release(e);} return result.ToArray();
  }
  public static string Default(int role) {
   var e=(IMMDeviceEnumerator)new MMEnumerator(); IMMDevice d=null;
   try {Check(e.GetDefaultAudioEndpoint(0,role,out d));string id;Check(d.GetId(out id));return id;}
   finally {Release(d);Release(e);}
  }
  public static void SetDefault(string id) {
   var e=(IMMDeviceEnumerator)new MMEnumerator(); IMMDevice d=null;
   try {Check(e.GetDevice(id,out d));uint state;Check(d.GetState(out state));if(state!=1)throw new InvalidOperationException("Endpoint is not active: "+id);}
   finally {Release(d);Release(e);}
   var p=(IPolicyConfig)new PolicyClient();
   try {Check(p.SetDefaultEndpoint(id,0));Check(p.SetDefaultEndpoint(id,1));}
   finally {Release(p);}
  }
 }
}
