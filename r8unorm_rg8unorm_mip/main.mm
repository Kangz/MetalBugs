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

// The number of mip levels of the texture (the last one is used for the test).
// 1 and 2 work, 3 and above fails.
static const NSUInteger kMipLevels = 3;

// The pixel format to test. R8Unorm and RG8Unorm fail. Others should work. Test with:
//   - R8Unorm and 1
//   - RG8Unorm and 2
//   - R16Unorm and 2
//   - RG16Unorm and 4
static const MTLPixelFormat kFormat = MTLPixelFormatR8Unorm;
static const size_t kBufferBytesToCheck = 1;

int main() {
    // Get the Intel device in dual-GPU systems by getting the UMA one.
    id<MTLDevice> device = nil;

    auto devices = MTLCopyAllDevices();
    for (id d in devices) {
        if ([d hasUnifiedMemory]) {
            device = d;
            break;
        }
    }

    if (!device) {
        std::cout << "No candidate Intel device found :(" << std::endl;
        return 1;
    }
    std::cout << "Device is " << [[device name] UTF8String] << std::endl;

    // Create the test texture.
    auto desc = [MTLTextureDescriptor new];
    desc.width = 1 << kMipLevels;
    desc.height = 1 << kMipLevels;
    desc.mipmapLevelCount = kMipLevels;
    desc.pixelFormat = kFormat;
    desc.textureType = MTLTextureType2D;
    desc.storageMode = MTLStorageModePrivate;
    desc.usage = MTLTextureUsageRenderTarget;
    auto texture = [device newTextureWithDescriptor:desc];

    // Create the readback buffer.
    auto buffer = [device newBufferWithLength:256 options:MTLResourceStorageModeShared];

    // Start encoding stuff.
    auto queue = [device newCommandQueue];
    auto commands = [queue commandBuffer];

    // Clear the texture using a render pass.
    auto rpDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    rpDesc.colorAttachments[0].texture = texture;
    rpDesc.colorAttachments[0].level = kMipLevels - 1;
    rpDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    rpDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    rpDesc.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    auto renderEncoder = [commands renderCommandEncoderWithDescriptor:rpDesc];
    [renderEncoder endEncoding];

    // Copy the mip level to the buffer.
    auto blitEncoder = [commands blitCommandEncoder];
    [blitEncoder copyFromTexture:texture
                     sourceSlice:0
                     sourceLevel:kMipLevels - 1
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(1, 1, 1)
                        toBuffer:buffer
               destinationOffset:0
          destinationBytesPerRow:16 
        destinationBytesPerImage:16];
    [blitEncoder endEncoding];

    [commands commit];
    [commands waitUntilCompleted];

    // Check the content of the buffer starts with 0xFF
    const uint8_t* bufferData = static_cast<const uint8_t*>([buffer contents]);
    for (size_t i = 0; i < kBufferBytesToCheck; i++) {
        if (bufferData[i] != 0xFF) {
            std::cout << "bufferData[" << i << "] is not 0xFF" << std::endl;
        }
    }

    return 0;
}
