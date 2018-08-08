import Foundation
import Metal

public func defaultVertexFunctionNameForInputs(_ inputCount:UInt) -> String {
    switch inputCount {
    case 1:
        return "oneInputVertex"
    case 2:
        return "twoInputVertex"
    default:
        return "oneInputVertex"
    }
}

open class BasicOperation: ImageProcessingOperation {
    
    public let maximumInputs: UInt
    public let targets = TargetContainer()
    public let sources = SourceContainer()
    
    public var activatePassthroughOnNextFrame:Bool = false
    public var uniformSettings = ShaderUniformSettings()

    let renderPipelineState: MTLRenderPipelineState
    let operationName: String
    var inputTextures = [UInt:Texture]()
    let textureInputSemaphore = DispatchSemaphore(value:1)
    var useNormalizedTextureCoordinates = true

    public init(vertexFunctionName: String? = nil,
                fragmentFunctionName: String,
                numberOfInputs: UInt = 1,
                operationName: String = #file) {
        self.maximumInputs = numberOfInputs
        self.operationName = operationName
        
        let concreteVertexFunctionName = vertexFunctionName ?? defaultVertexFunctionNameForInputs(numberOfInputs)
        renderPipelineState = generateRenderPipelineState(device:sharedMetalRenderingDevice, vertexFunctionName:concreteVertexFunctionName, fragmentFunctionName:fragmentFunctionName, operationName:operationName)
    }
    
    public func transmitPreviousImage(to target: ImageConsumer, atIndex: UInt) {
        // TODO: Finish implementation later
    }
    
    public func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        inputTextures[fromSourceIndex] = texture

        guard (!activatePassthroughOnNextFrame) else { // Use this to allow a bootstrap of cyclical processing, like with a low pass filter
            activatePassthroughOnNextFrame = false
            //            updateTargetsWithTexture(outputTexture) // TODO: Fix this
            return
        }
        
        if (UInt(inputTextures.count) >= maximumInputs) {
            let outputWidth:Int
            let outputHeight:Int
            
            let firstInputTexture = inputTextures[0]!
            if firstInputTexture.orientation.rotationNeeded(for:.portrait).flipsDimensions() {
                outputWidth = firstInputTexture.texture.height
                outputHeight = firstInputTexture.texture.width
            } else {
                outputWidth = firstInputTexture.texture.width
                outputHeight = firstInputTexture.texture.height
            }
            
            guard let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() else {return}

            let outputTexture = Texture(device:sharedMetalRenderingDevice.device, orientation: .portrait, width: outputWidth, height: outputHeight)
            
            commandBuffer.renderQuad(pipelineState: renderPipelineState, uniformSettings: uniformSettings, inputTextures: inputTextures, useNormalizedTextureCoordinates: useNormalizedTextureCoordinates, outputTexture: outputTexture)
            commandBuffer.commit()
            
            updateTargetsWithTexture(outputTexture)
        }
    }
}
