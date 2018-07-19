import Foundation
import MetalKit

public class RenderView: MTKView, ImageConsumer {
  
  public let sources = SourceContainer()
  public let maximumInputs: UInt = 1
  var currentTexture: Texture?
  var renderPipelineState:MTLRenderPipelineState!
  let inFlightSemaphore = DispatchSemaphore(value: 2)
  
  public override init(frame frameRect: CGRect, device: MTLDevice?) {
    super.init(frame: frameRect, device: device)
    
    commonInit()
  }
  
  public required init(coder: NSCoder) {
    super.init(coder: coder)
    
    commonInit()
  }
  
  private func commonInit() {
    framebufferOnly = false
    autoResizeDrawable = true
    
    self.device = sharedMetalRenderingDevice.device
    
    renderPipelineState = generateRenderPipelineState(device:sharedMetalRenderingDevice, vertexFunctionName:"oneInputVertex", fragmentFunctionName:"passthroughFragment", operationName:"RenderView")
    
    enableSetNeedsDisplay = false
    isPaused = true
  }
  
  public func newTextureAvailable(_ texture:Texture, fromSourceIndex:UInt) {
    self.drawableSize = CGSize(width: texture.texture.width, height: texture.texture.height)
    currentTexture = texture
    self.draw()
    
  }
  
  
  public override func draw(_ rect:CGRect) {
    _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
    
    if let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() {
      let semaphore = inFlightSemaphore
      commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
        semaphore.signal()
      }
      
      if let currentDrawable = self.currentDrawable,
        let imageTexture = currentTexture {
        
        let outputTexture = Texture(orientation: .portrait, texture: currentDrawable.texture)
        
        commandBuffer.renderQuad(pipelineState: renderPipelineState, inputTextures: [0:imageTexture], outputTexture: outputTexture)
        
        commandBuffer.present(currentDrawable)
        
      }
      
      commandBuffer.commit()
      
    }
  }
}


