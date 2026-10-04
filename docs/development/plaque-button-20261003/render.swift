import SwiftUI
import AppKit
let art = NSImage(contentsOfFile: CommandLine.arguments[1])!
struct Old: View { var body: some View {
    Text("继续 · 前往后续").font(.system(size: 18, weight: .bold, design: .serif)).tracking(1)
        .foregroundStyle(Color(red: 0.14, green: 0.12, blue: 0.16))
        .frame(maxWidth: .infinity, minHeight: 62).padding(.horizontal, 20)
        .background { Image(nsImage: art).resizable(capInsets: EdgeInsets(top: 25, leading: 120, bottom: 25, trailing: 120), resizingMode: .stretch) }
} }
struct New: View { var body: some View {
    Text("继续 · 前往后续").font(.system(size: 18, weight: .bold, design: .serif)).tracking(1)
        .foregroundStyle(Color(red: 0.14, green: 0.12, blue: 0.16))
        .padding(.top, 17)
        .frame(maxWidth: .infinity, minHeight: 74).padding(.horizontal, 20)
        .background { Image(nsImage: art).resizable() }
} }
struct Sheet: View { var body: some View {
    VStack(spacing: 30) {
        Text("改前").foregroundStyle(.white); Old()
        Text("改后").foregroundStyle(.white); New()
        Text("改后（不铺满宽度）").foregroundStyle(.white); New().frame(width: 230)
    }.padding(24).frame(width: 394).background(Color(red: 0.05, green: 0.045, blue: 0.1))
} }
@MainActor func run() {
    let r = ImageRenderer(content: Sheet()); r.scale = 2
    let img = r.nsImage!
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
MainActor.assumeIsolated { run() }
