//
//  Shaders.metal
//  Breakout Shared
//
//  Created by Richard Pickup on 14/03/2022.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

struct SpriteIn {
    float2 position [[attribute(Position)]];
    float2 uv [[attribute(UV)]];
    float4 color [[attribute(3)]];
};

struct SpriteOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
};


struct SimplePipelineRasterizerData
{
    float4 position [[position]];
    float4 color;
};

struct TexturePipelineRasterizerData
{
    float4 position [[position]];
    float2 texcoord;
};

vertex TexturePipelineRasterizerData
simpleVertexShader(const uint vertexID [[ vertex_id ]],
                   const device AAPLTextureVertex *vertices [[ buffer(AAPLVertexInputIndexVertices) ]],
                   constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    TexturePipelineRasterizerData out;
    
    out.position = vector_float4(vertices[vertexID].position.xy, 0.0, 1.0);
    
    float2 texture = vertices[vertexID].texcoord.xy;
    
    if (uniforms.chaos) {
        float strength = 0.3;
        float2 pos = float2(texture.x + sin(uniforms.time) * strength,
                            texture.y + cos(uniforms.time) * strength);
        
        out.texcoord = pos;
    } else if (uniforms.confuse) {
        out.texcoord = float2(1.0 - texture.x, 1.0 - texture.y);
    } else {
        out.texcoord = texture;
    }
    
    if (uniforms.shake) {
        float strength = 0.01;
        
        out.position.x += cos(uniforms.time * 10) * strength;
        out.position.y += cos(uniforms.time * 15) * strength;
    }
    
    return out;
}

// Fragment shader that just outputs color passed from rasterizer.
fragment float4 simpleFragmentShader(TexturePipelineRasterizerData in [[stage_in]],
                                     texture2d<float> texture [[texture(AAPLTextureInputIndexColor)]],
                                     constant Uniforms &uniforms [[buffer(BufferIndexFragmentUniforms)]])
{
    sampler simpleSampler(filter::linear,
                          address::repeat);
    
    
    float4 color = float4(0.0f);
    
    // Sample data from the texture.
    //float4 colorSample = texture.sample(simpleSampler, in.texcoord);
    float3 sample[9];
    if (uniforms.chaos || uniforms.shake) {
        for(int i = 0; i < 9; i++) {
            sample[i] = float3(texture.sample(simpleSampler, in.texcoord.xy + uniforms.offsets[i]));
        }
    }
    
    if (uniforms.chaos) {
        for (int i = 0; i < 9; i++) {
            color += float4(sample[i] * uniforms.edge_kernel[i], 0.0f);
        }
        color.a = 1.0f;
    } else if (uniforms.confuse) {
        color = float4(1.0 - texture.sample(simpleSampler, in.texcoord).rgb, 1.0f);
    } else if (uniforms.shake) {
        for (int i = 0; i < 9; i++) {
            color += float4(sample[i] * uniforms.blur_kernel[i], 0.0f);
        }
        color.a = 1.0f;
    } else {
        color = texture.sample(simpleSampler, in.texcoord);
    }
    
    // Return the color sample as the final color.
    return color;
}


vertex SpriteOut sprite_vertex(const SpriteIn vertexIn [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {
    SpriteOut out {
        .position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertexIn.position, 0, 1),
        
        .uv = vertexIn.uv,
        
        .color = vertexIn.color
    };
    
    return out;
}

fragment float4 sprite_frag (SpriteOut in  [[stage_in]],
                             texture2d<float> baseColorTexture [[texture(BaseColorTexture)]],
                             sampler textureSampler [[sampler(0)]]) {
    
    float4 baseColor = baseColorTexture.sample(textureSampler,
                                               in.uv).rgba;
    
    return in.color * baseColor;
    
}
