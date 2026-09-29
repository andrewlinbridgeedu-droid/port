// Native UI QA helper. Only local.mistport.workshop-playtest is accessible.
// Use only when the user has authorized native automation for this isolated app.
import AppKit
import ApplicationServices
import Foundation
let bundleID = "local.mistport.workshop-playtest"
func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil }
func str(_ e: AXUIElement, _ name: String) -> String { (attr(e,name) as? String) ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { (attr(e,kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func fail(_ s: String) -> Never { fputs(s+"\n", stderr);exit(1) }
guard AXIsProcessTrusted() else { fail("AX_NOT_TRUSTED") }
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
guard apps.count == 1, let app = apps.first else { fail("Expected exactly one isolated workshop app; found \(apps.count)") }
let root = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(root, 3)
var nodes: [(AXUIElement,Int)] = []
func walk(_ e: AXUIElement, _ depth: Int) { guard depth < 18, nodes.count < 1500 else{return}; nodes.append((e,depth)); for child in children(e) where str(child,kAXRoleAttribute) != "AXMenuBar" { walk(child,depth+1) } }
walk(root,0)
let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "dump"
if cmd == "dump" {
 var rows: [[String:Any]] = []
 for (i,pair) in nodes.enumerated() {
  let (e,d)=pair; let role=str(e,kAXRoleAttribute)
  var row:[String:Any] = ["i":i,"depth":d,"role":role]
  for (key,ax) in [("title",kAXTitleAttribute),("description",kAXDescriptionAttribute),("value",kAXValueAttribute),("identifier",kAXIdentifierAttribute)] {
   if let v=attr(e,ax) { row[key] = String(describing:v) }
  }
  if let v=attr(e,kAXEnabledAttribute) {row["enabled"] = String(describing:v)}
  rows.append(row)
 }
 let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []).filter { ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier) }
 let out:[String:Any] = ["pid":app.processIdentifier,"nodes":rows,"windows":windows]
 let data=try JSONSerialization.data(withJSONObject:out,options:[.prettyPrinted,.sortedKeys]); FileHandle.standardOutput.write(data)
 } else if cmd == "press-text", args.count == 2 {
 let matches = nodes.filter { p in
  let r=str(p.0,kAXRoleAttribute)
  return ["AXButton","AXProgressIndicator","AXRadioButton","AXCheckBox","AXPopUpButton","AXMenuItem"].contains(r) && (str(p.0,kAXDescriptionAttribute).hasPrefix(args[1]) || str(p.0,kAXTitleAttribute) == args[1])
 }
 guard matches.count == 1 else { fail("Expected one matching control: \(matches.count)") }
 let e=matches[0].0
 guard (attr(e,kAXEnabledAttribute) as? Bool) != false else { fail("Control disabled") }
 let result=AXUIElementPerformAction(e,kAXPressAction as CFString)
 print("press-text",args[1],result.rawValue)
 guard result == .success else { exit(2) }
} else if cmd == "press", args.count == 2, let i=Int(args[1]), nodes.indices.contains(i) {
 let e=nodes[i].0
 let result=AXUIElementPerformAction(e,kAXPressAction as CFString)
 print("press",i,str(e,kAXTitleAttribute),result.rawValue)
 guard result == .success else {exit(2)}
} else { fail("Use dump or press <fresh index>") }
