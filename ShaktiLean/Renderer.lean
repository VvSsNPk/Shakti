import ShaktiLean.Basic
import ShaktiLean.EventLoop
import ShaktiLean.GraphicsFFI

namespace WaylandProtocol

-- Region for damage tracking
structure Region where
  x : Int32
  y : Int32
  width : Nat
  height : Nat

-- Surface rendering data
structure SurfaceRenderData where
  surfaceId : UInt32
  width : Nat
  height : Nat
  textureId : Option Texture
  needsRedraw : Bool
  damageRegions : List Region

-- Output rendering state
structure OutputRenderState where
  outputId : Nat
  width : Nat
  height : Nat
  framebuffer : Option Framebuffer
  renderPass : Nat

-- Frame state
structure FrameState where
  frameNumber : Nat
  targetFPS : Nat
  frameTime : Nat
  deltaTime : Nat
  droppedFrames : Nat

def FrameState.create : FrameState :=
  ⟨0, 60, 0, 0, 0⟩

-- Renderer state
structure RendererState where
  context : RenderingContext
  surfaces : List SurfaceRenderData
  outputs : List OutputRenderState
  frameState : FrameState
  program : Option Program

def RendererState.create : RendererState :=
  ⟨RenderingContext.create, [], [], FrameState.create, none⟩

-- Initialize renderer
def initializeRenderer (width height : Nat) : IO RendererState := do
  glClearColor 0.0 0.0 0.0 1.0

  glViewport (0 : Int32) (0 : Int32) (Int32.ofNat width) (Int32.ofNat height)

  let program ← createSimpleProgram

  let ctx := RenderingContext.create.initialize width height
  pure ⟨ctx, [], [], FrameState.create, program⟩

-- Register surface
def registerSurface (renderer : RendererState) (surfaceId : UInt32) (width height : Nat) :
    RendererState :=
  let surfaceData : SurfaceRenderData := ⟨surfaceId, width, height, none, true, []⟩
  { renderer with surfaces := renderer.surfaces ++ [surfaceData] }

-- Mark surface dirty
def markSurfaceDirty (renderer : RendererState) (surfaceId : UInt32) :
    RendererState :=
  let updatedSurfaces := renderer.surfaces.map (fun s =>
    if s.surfaceId == surfaceId then { s with needsRedraw := true } else s)
  { renderer with surfaces := updatedSurfaces }

-- Add damage region
def addDamageRegion (renderer : RendererState) (surfaceId : UInt32) (region : Region) :
    RendererState :=
  let updatedSurfaces := renderer.surfaces.map (fun s =>
    if s.surfaceId == surfaceId then { s with damageRegions := s.damageRegions ++ [region] } else s)
  { renderer with surfaces := updatedSurfaces }

-- Find surface
def findSurface (renderer : RendererState) (surfaceId : UInt32) :
    Option SurfaceRenderData :=
  renderer.surfaces.find? (fun s => s.surfaceId == surfaceId)

-- Clear damage
def clearSurfaceDamage (renderer : RendererState) (surfaceId : UInt32) :
    RendererState :=
  let updatedSurfaces := renderer.surfaces.map (fun s =>
    if s.surfaceId == surfaceId then { s with damageRegions := [], needsRedraw := false } else s)
  { renderer with surfaces := updatedSurfaces }

-- Render frame
def renderFrame (renderer : RendererState) : IO RendererState := do
  glClear GL.COLOR_BUFFER_BIT

  match renderer.program with
  | some prog => glUseProgram prog
  | none => pure ()

  for surface in renderer.surfaces do
    if surface.needsRedraw then
      pure ()

  glFlush

  let updatedFrame := { renderer.frameState with
    frameNumber := renderer.frameState.frameNumber + 1,
    deltaTime := 16
  }

  pure { renderer with frameState := updatedFrame }

-- Render with compositor
def renderCompositorFrame (renderer : RendererState) (compositor : CompositorState) :
    IO (RendererState × CompositorState) := do
  let updatedRenderer ← renderFrame renderer
  let updatedCompositor := { compositor with frameTime := compositor.frameTime + 16 }
  pure (updatedRenderer, updatedCompositor)

-- Render stats
structure RenderStats where
  frameNumber : Nat
  fps : Nat
  droppedFrames : Nat
  activeSurfaces : Nat
  texturesInVRAM : Nat

def getRenderStats (renderer : RendererState) : RenderStats :=
  let activeSurfaces := renderer.surfaces.filter (fun s => s.needsRedraw)
  let texturesInVRAM := renderer.surfaces.filterMap (fun s => s.textureId) |>.length
  ⟨renderer.frameState.frameNumber, renderer.frameState.targetFPS,
   renderer.frameState.droppedFrames, activeSurfaces.length, texturesInVRAM⟩

-- Clear surfaces
def clearAllSurfaces (renderer : RendererState) : RendererState :=
  { renderer with surfaces := [] }

-- Shutdown
def shutdownRenderer (renderer : RendererState) : IO Unit := do
  glFinish

-- Set program
def setRenderProgram (renderer : RendererState) (program : Program) : RendererState :=
  { renderer with program := some program }

-- Stats to string
def renderStatsToString (stats : RenderStats) : String :=
  s!"Frame: {stats.frameNumber} | FPS: {stats.fps} | Surfaces: {stats.activeSurfaces} | VRAM: {stats.texturesInVRAM}"

end WaylandProtocol
