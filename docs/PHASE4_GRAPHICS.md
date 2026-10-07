# Phase 4: Graphics Rendering & OpenGL ES FFI Bindings

## Overview

Phase 4 adds graphics rendering capabilities through OpenGL ES FFI (Foreign Function Interface) bindings. It provides:
- **Safe OpenGL ES wrapper** - Type-safe Lean 4 interface to GL functions
- **Rendering context** - Manage GPU state and shader programs
- **Surface rendering** - Track and render Wayland surfaces
- **Damage tracking** - Efficient region-based rendering
- **Frame statistics** - Monitor rendering performance

## Architecture

```
┌──────────────────────────────────────────────────┐
│     Compositor + Renderer Integration           │
├──────────────────────────────────────────────────┤
│                                                  │
│  renderCompositorFrame()                        │
│  ├─ Process messages (EventLoop)                │
│  ├─ Render frame (Renderer)                     │
│  └─ Update GPU state (GraphicsFFI)              │
│                                                  │
├──────────────────────────────────────────────────┤
│     Renderer State                              │
│  - Surface tracking                             │
│  - Damage regions                               │
│  - Frame statistics                             │
│  - Shader programs                              │
│                                                  │
├──────────────────────────────────────────────────┤
│     GraphicsFFI Safe Wrappers                   │
│  - glClear, glViewport                          │
│  - glCreateShader, glLinkProgram                │
│  - glDrawArrays, glDrawElements                 │
│  - glBindBuffer, glBindTexture                  │
│                                                  │
├──────────────────────────────────────────────────┤
│     OpenGL ES C Library (via FFI)               │
│  - Native GPU operations                        │
│  - State management                             │
│  - Rendering pipeline                          │
│                                                  │
└──────────────────────────────────────────────────┘
```

## OpenGL ES Types & Constants

### Type Definitions

```lean
abbrev GLuint := UInt32          -- GL object handle
abbrev GLint := Int32            -- GL signed integer
abbrev GLfloat := Float          -- GL float
abbrev GLboolean := UInt8        -- GL boolean (0/1)
abbrev GLenum := UInt32          -- GL enumeration
```

### Key Constants

```lean
GL.COLOR_BUFFER_BIT := 0x00004000
GL.DEPTH_BUFFER_BIT := 0x00000100
GL.TRIANGLES := 0x0004
GL.ARRAY_BUFFER := 0x8892
GL.STATIC_DRAW := 0x88E4
GL.VERTEX_SHADER := 0x8B31
GL.FRAGMENT_SHADER := 0x8B30
GL.TEXTURE_2D := 0x0DE1
GL.RGBA := 0x1908
```

## Handles

Type-safe wrappers around GL object IDs:

```lean
structure Shader where
  id : GLuint

structure Program where
  id : GLuint

structure Buffer where
  id : GLuint

structure Texture where
  id : GLuint

structure Framebuffer where
  id : GLuint
```

## FFI Bindings

Safe Lean 4 wrappers around OpenGL ES C functions:

### State Management

```lean
def glClearColor (r g b a : Float) : IO Unit
def glClear (mask : GLenum) : IO Unit
def glViewport (x y : Int32) (width height : Int32) : IO Unit
def glUseProgram (program : Program) : IO Unit
def glFlush : IO Unit
def glFinish : IO Unit
```

### Shader Operations

```lean
def glCreateShader (shaderType : GLenum) : IO Shader
def glShaderSource (shader : Shader) (source : String) : IO Unit
def glCompileShader (shader : Shader) : IO Unit
def glCreateProgram : IO Program
def glAttachShader (program : Program) (shader : Shader) : IO Unit
def glLinkProgram (program : Program) : IO Unit
```

### Buffer Operations

```lean
def glBindBuffer (target : GLenum) (buffer : Buffer) : IO Unit
def glBufferData (target : GLenum) (data : ByteArray) (usage : GLenum) : IO Unit
```

### Texture Operations

```lean
def glBindTexture (target : GLenum) (texture : Texture) : IO Unit
def glTexParameteri (target : GLenum) (pname : GLenum) (param : Int32) : IO Unit
```

### Vertex Attributes

```lean
def glEnableVertexAttribArray (index : UInt32) : IO Unit
def glVertexAttribPointer (index : UInt32) (size : Int32) (type_ : GLenum)
    (normalized : Bool) (stride : Int32) (offset : Nat) : IO Unit
```

### Drawing

```lean
def glDrawArrays (mode : GLenum) (first : Int32) (count : Int32) : IO Unit
def glDrawElements (mode : GLenum) (count : Int32) (type_ : GLenum) (offset : Nat) : IO Unit
```

## Rendering Context

Manages GPU state:

```lean
structure RenderingContext where
  isInitialized : Bool
  activeProgram : Option Program
  viewportWidth : Nat
  viewportHeight : Nat
```

## Renderer State

Complete rendering state for the compositor:

```lean
structure Region where
  x : Int32
  y : Int32
  width : Nat
  height : Nat

structure SurfaceRenderData where
  surfaceId : UInt32
  width : Nat
  height : Nat
  textureId : Option Texture
  needsRedraw : Bool
  damageRegions : List Region

structure FrameState where
  frameNumber : Nat
  targetFPS : Nat
  frameTime : Nat
  deltaTime : Nat
  droppedFrames : Nat

structure RendererState where
  context : RenderingContext
  surfaces : List SurfaceRenderData
  outputs : List OutputRenderState
  frameState : FrameState
  program : Option Program
```

## Renderer API

### Initialization

```lean
def initializeRenderer (width height : Nat) : IO RendererState
```

Initialize GPU for rendering at specified resolution.

### Surface Management

```lean
def registerSurface (renderer : RendererState) (surfaceId : UInt32) 
    (width height : Nat) : RendererState

def markSurfaceDirty (renderer : RendererState) (surfaceId : UInt32) : RendererState

def addDamageRegion (renderer : RendererState) (surfaceId : UInt32) 
    (region : Region) : RendererState

def findSurface (renderer : RendererState) (surfaceId : UInt32) : 
    Option SurfaceRenderData

def clearSurfaceDamage (renderer : RendererState) (surfaceId : UInt32) : RendererState
```

### Rendering

```lean
def renderFrame (renderer : RendererState) : IO RendererState

def renderCompositorFrame (renderer : RendererState) (compositor : CompositorState) :
    IO (RendererState × CompositorState)
```

Render one frame of the compositor.

### Statistics

```lean
structure RenderStats where
  frameNumber : Nat
  fps : Nat
  droppedFrames : Nat
  activeSurfaces : Nat
  texturesInVRAM : Nat

def getRenderStats (renderer : RendererState) : RenderStats
def renderStatsToString (stats : RenderStats) : String
```

### Program Management

```lean
def createSimpleProgram : IO (Option Program)
def setRenderProgram (renderer : RendererState) (program : Program) : RendererState
```

### Cleanup

```lean
def shutdownRenderer (renderer : RendererState) : IO Unit
def clearAllSurfaces (renderer : RendererState) : RendererState
```

## Usage Examples

### Example 1: Initialize Renderer

```lean
open WaylandProtocol

-- Create renderer for 1920x1080 display
let renderer ← initializeRenderer 1920 1080

#eval renderer.context.isInitialized     -- true
#eval renderer.context.viewportWidth     -- 1920
#eval renderer.frameState.frameNumber    -- 0
```

### Example 2: Register and Render Surface

```lean
-- Register a surface
let renderer1 := registerSurface renderer 1 1920 1080

-- Mark for redraw
let renderer2 := markSurfaceDirty renderer1 1

-- Render frame
let renderer3 ← renderFrame renderer2

#eval renderer3.frameState.frameNumber    -- 1
```

### Example 3: Damage Tracking

```lean
-- Add damage region (dirty rectangle)
let region := Region.mk 0 0 100 100
let renderer4 := addDamageRegion renderer3 1 region

-- Render only affected areas
let renderer5 ← renderFrame renderer4

-- Clear damage after render
let renderer6 := clearSurfaceDamage renderer5 1
```

### Example 4: Compositor Integration

```lean
-- Create compositor and renderer
let comp := CompositorState.create
let renderer ← initializeRenderer 1920 1080

-- Render frame with both compositor and graphics
let (renderer', comp') ← renderCompositorFrame renderer comp

#eval comp'.frameTime        -- 16 (16ms per frame)
#eval renderer'.frameState.frameNumber  -- 1
```

### Example 5: Monitor Performance

```lean
-- Run compositor loop with rendering
let comp := CompositorState.create
let renderer ← initializeRenderer 1920 1080

-- Simulate 60 frames
let rec renderLoop (r : RendererState) (c : CompositorState) (n : Nat) :
    IO (RendererState × CompositorState) :=
  if n == 0 then pure (r, c)
  else do
    let (r', c') ← renderCompositorFrame r c
    renderLoop r' c' (n - 1)

let (finalRenderer, finalComp) ← renderLoop renderer comp 60

-- Get statistics
let stats := getRenderStats finalRenderer
IO.println (renderStatsToString stats)
-- Output: "Frame: 60 | FPS: 60 | Surfaces: 1 | VRAM: 0"
```

## FFI Safety

### Why FFI is Safe Here

1. **Type-safe wrappers** - GL handles are wrapped in structures
2. **IO monad** - All GPU operations are in IO, making effects explicit
3. **No null pointers** - Option types for optional values
4. **Bounded by compositor** - Renderer integrates with EventLoop

### Real Implementation Notes

For production use, you would:

1. **Link actual GL library**
   ```
   -- In lakefile.lean, add GL library linking
   ```

2. **Replace stub functions**
   ```lean
   @[extern "glClearColor"]
   opaque glClearColor_ffi (r g b a : Float) : IO Unit
   ```

3. **Add error handling**
   ```lean
   def glGetError : IO GLenum := ...
   def checkGLError : IO (Option String) := ...
   ```

4. **Implement texture upload**
   ```lean
   def glTexImage2D_ffi (...) : IO Unit := ...
   ```

## Integration with Compositor

### Unified Rendering Loop

```lean
def compositorWithRendering (comp : CompositorState) (renderer : RendererState) 
    (iterations : Nat) : IO (CompositorState × RendererState) := do
  let rec loop (c : CompositorState) (r : RendererState) (n : Nat) :
      IO (CompositorState × RendererState) :=
    if n == 0 then pure (c, r)
    else do
      -- Process messages
      let c' := compositorIteration c
      
      -- Render graphics
      let (r', c'') ← renderCompositorFrame r c'
      
      -- Continue
      loop c'' r' (n - 1)
  
  loop comp renderer iterations
```

## Performance Characteristics

- **Clear screen**: O(1) GPU operation
- **Render surface**: O(pixels) GPU bandwidth
- **Damage tracking**: O(regions) to process damage
- **Frame time**: 16ms at 60fps

## Next Steps for Production

1. **Link real OpenGL ES library**
   - libGLESv2, EGL, or equivalent
   - Platform-specific: Android, Linux, etc.

2. **Implement buffer pooling**
   - Reuse GPU buffers
   - Avoid allocation stalls

3. **Add texture management**
   - Upload surface buffers to GPU
   - Manage VRAM efficiently

4. **Implement render queue**
   - Batch render operations
   - Optimize state changes

5. **Add shading system**
   - Custom shaders per surface type
   - Effects pipeline

6. **Frame timing**
   - VSync synchronization
   - Frame callbacks for clients

---

**Phase 4 provides the graphics foundation for a real Wayland compositor!** 🎨

You now have type-safe OpenGL ES bindings that integrate seamlessly with the compositor event loop. The next step would be to link actual GL libraries and implement the full rendering pipeline.
