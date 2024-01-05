// Compile and run with:
//
//    clang++ main.mm -o bug -framework Metal -framework Cocoa -std=c++17 && ./bug
//
// To enable Metal debug devices first do:
//
//    export METAL_DEVICE_WRAPPER_TYPE=1

#import <Metal/Metal.h>
#include <iostream>

// TEST PARAMERTERS TO PLAY WITH

// The pixel format to test. R8Uint
static const MTLPixelFormat kFormat = MTLPixelFormatR8Uint;

int main() {
    auto device = MTLCreateSystemDefaultDevice();
    std::cout << "Device is " << [[device name] UTF8String] << std::endl;
    auto queue = [device newCommandQueue];

    // Create the test texture.
    auto desc = [MTLTextureDescriptor new];
    desc.width = 32;
    desc.height = 16;
    desc.mipmapLevelCount = 1;
    desc.pixelFormat = kFormat;
    desc.textureType = MTLTextureType2D;
    desc.storageMode = MTLStorageModePrivate;
    desc.usage = MTLTextureUsageRenderTarget;
    auto texture = [device newTextureWithDescriptor:desc];

    // Create the readback buffer.
    auto buffer = [device newBufferWithLength:256*16 options:MTLResourceStorageModeShared];

    // Clear the texture using a render pass.
    auto rpDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    rpDesc.colorAttachments[0].texture = texture;
    rpDesc.colorAttachments[0].level = 0;
    rpDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    rpDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    rpDesc.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 0.0);

    auto commands = [queue commandBuffer];
    auto renderEncoder = [commands renderCommandEncoderWithDescriptor:rpDesc];
    [renderEncoder endEncoding];

    // Copy the mip level to the buffer.
    auto blitEncoder = [commands blitCommandEncoder];
    [blitEncoder copyFromTexture:texture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(32, 16, 1)
                        toBuffer:buffer
               destinationOffset:0
          destinationBytesPerRow:256
        destinationBytesPerImage:0];
    [blitEncoder endEncoding];
    [commands commit];
    [commands waitUntilCompleted];


    // Check the content of the buffer starts with 0xFF
    const uint8_t* bufferData = static_cast<const uint8_t*>([buffer contents]);
    for (size_t i = 0; i < 32; i++) {
        if (bufferData[i] != 0x1) {
            std::cout << "bufferData[" << i << "] is not 0x1" << std::endl;
        }
    }

    return 0;
}
