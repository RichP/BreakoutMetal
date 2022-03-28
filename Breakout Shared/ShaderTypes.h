//
//  ShaderTypes.h
//  Breakout Shared
//
//  Created by Richard Pickup on 14/03/2022.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 11,
    BufferIndexLights = 12,
    BufferIndexFragmentUniforms = 13,
    BufferIndexMaterials = 14
} BufferIndices;

typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices    = 0,
    AAPLVertexInputIndexAspectRatio = 1,
} AAPLVertexInputIndex;

typedef enum AAPLTextureInputIndex
{
    AAPLTextureInputIndexColor = 0,
} AAPLTextureInputIndex;

typedef enum {
    Position = 0,
    Normal = 1,
    UV = 2,
    Tangent = 3,
    Bitangent = 4,
    Color = 5
} Attributes;

typedef enum {
    BaseColorTexture = 0,
    NormalTexture = 1
} Textures;

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    bool chaos;
    bool confuse;
    bool shake;
    float time;
    
    vector_float2 offsets[9];
    int edge_kernel[9];
    float blur_kernel[9];
} Uniforms;

typedef struct
{
    vector_float2 position;
    vector_float4 color;
} AAPLSimpleVertex;

typedef struct
{
    vector_float2 position;
    vector_float2 texcoord;
} AAPLTextureVertex;

#endif /* ShaderTypes_h */

