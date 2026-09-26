import Foundation
import AVFoundation
import AppKit
let directory=URL(fileURLWithPath:CommandLine.arguments[1])
let output=URL(fileURLWithPath:CommandLine.arguments[2])
let paths=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("frame-") && $0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
guard let first=NSImage(contentsOf:paths[0]),let cg=first.cgImage(forProposedRect:nil,context:nil,hints:nil) else {fatalError("Missing frame")}
try? FileManager.default.removeItem(at:output)
let writer=try AVAssetWriter(outputURL:output,fileType:.mp4)
let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:cg.width,AVVideoHeightKey:cg.height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000]])
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:cg.width,kCVPixelBufferHeightKey as String:cg.height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
for (index,path) in paths.enumerated(){
 while !input.isReadyForMoreMediaData {Thread.sleep(forTimeInterval:0.005)}
 try autoreleasepool {
 guard let image=NSImage(contentsOf:path)?.cgImage(forProposedRect:nil,context:nil,hints:nil) else {fatalError("Bad frame")}
 var pixel:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&pixel)
 let buffer=pixel!;CVPixelBufferLockBaseAddress(buffer,[])
 let context=CGContext(data:CVPixelBufferGetBaseAddress(buffer),width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(buffer),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
 context.draw(image,in:CGRect(x:0,y:0,width:cg.width,height:cg.height));CVPixelBufferUnlockBaseAddress(buffer,[])
 if !adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(index),timescale:15)){throw writer.error!}
 }
}
input.markAsFinished()
writer.finishWriting {print(writer.status == .completed ? output.path : "FAILED: \(String(describing:writer.error))");exit(writer.status == .completed ? 0:1)}
dispatchMain()
