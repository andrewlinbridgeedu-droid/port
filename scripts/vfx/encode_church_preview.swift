import Foundation
import AVFoundation
import AppKit
let dir=URL(fileURLWithPath:CommandLine.arguments[1])
let files=try FileManager.default.contentsOfDirectory(atPath:dir.path)
let starts=files.filter{$0.hasSuffix("-00.png")}.sorted()
for first in starts {
 let stem=String(first.dropLast(7)), out=dir.appendingPathComponent(stem+".mp4")
 try? FileManager.default.removeItem(at:out)
 let writer=try AVAssetWriter(outputURL:out,fileType:.mp4)
 let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:720,AVVideoHeightKey:1280,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:6000000,AVVideoMaxKeyFrameIntervalKey:30]])
 let adapter=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:720,kCVPixelBufferHeightKey as String:1280,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
 writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
 for i in 0..<48 {
  while !input.isReadyForMoreMediaData {Thread.sleep(forTimeInterval:0.002)}
  try autoreleasepool {
   let path=dir.appendingPathComponent(String(format:"%@-%02d.png",stem,i))
   guard let image=NSImage(contentsOf:path),let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil) else {throw NSError(domain:"Missing frame",code:i)}
   var b:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adapter.pixelBufferPool!,&b);let pixel=b!;CVPixelBufferLockBaseAddress(pixel,[])
   let ctx=CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:720,height:1280,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
   ctx.draw(cg,in:CGRect(x:0,y:0,width:720,height:1280));CVPixelBufferUnlockBaseAddress(pixel,[])
   if !adapter.append(pixel,withPresentationTime:CMTime(value:Int64(i),timescale:30)){throw writer.error!}
  }
 }
 input.markAsFinished();let sem=DispatchSemaphore(value:0);writer.finishWriting{sem.signal()};sem.wait();if writer.status != .completed{throw writer.error!};print(stem)
}
